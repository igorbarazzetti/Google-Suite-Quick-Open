#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import mimetypes
import os
import re
import secrets
import sys
import threading
import time
import urllib.parse
import urllib.request
import webbrowser
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from typing import Any, Dict, Optional, Tuple
from urllib.error import HTTPError

APP_NAME = "GoogleDriveQuickOpen"
APP_DISPLAY_NAME = "Google Suite Quick Open"
STATE_FILE = Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData" / "Local")) / APP_NAME / "state.json"
STATE_FILE.parent.mkdir(parents=True, exist_ok=True)

CLIENT_SECRET_FILE = Path(__file__).resolve().parent / "client_secret.json"
DOC_EXTS = {".doc", ".docx", ".rtf", ".odt"}
SHEET_EXTS = {".xls", ".xlsx", ".csv", ".ods"}
SLIDE_EXTS = {".ppt", ".pptx"}
TOKEN_ENDPOINT = "https://oauth2.googleapis.com/token"
AUTH_ENDPOINT = "https://accounts.google.com/o/oauth2/v2/auth"
DRIVE_FILES_URL = "https://www.googleapis.com/drive/v3/files"
DRIVE_UPLOAD_URL = "https://www.googleapis.com/upload/drive/v3/files"
DRIVE_SCOPE = "https://www.googleapis.com/auth/drive.file"
TEMP_FOLDER_DEFAULT = os.environ.get("GD_QUICKOPEN_TEMP_FOLDER", f"{APP_NAME} Temp")
try:
DEFAULT_RETENTION_HOURS = int(os.environ.get("GD_QUICKOPEN_RETENTION_HOURS", "0"))
except ValueError:
    DEFAULT_RETENTION_HOURS = 24
FOLDER_MIME = "application/vnd.google-apps.folder"
FAST_OPEN = os.environ.get("GD_QUICKOPEN_FAST", "1").strip().lower() not in {"0", "false", "no", "off"}
CLEANUP_MIN_INTERVAL_HOURS = 6.0


def log(message: str) -> None:
    log_file = STATE_FILE.parent / "launcher.log"
    timestamp = time.strftime("%Y-%m-%d %H:%M:%S")
    with log_file.open("a", encoding="utf-8") as f:
        f.write(f"[{timestamp}] {message}\n")


def load_state() -> Dict[str, Any]:
    if not STATE_FILE.exists():
        return {"token": None, "files": {}, "settings": {}}
    try:
        with STATE_FILE.open("r", encoding="utf-8") as f:
            state = json.load(f)
        state.setdefault("token", None)
        state.setdefault("files", {})
        state.setdefault("settings", {})
        return state
    except Exception:
        return {"token": None, "files": {}, "settings": {}}


def save_state(state: Dict[str, Any]) -> None:
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    with STATE_FILE.open("w", encoding="utf-8") as f:
        json.dump(state, f, indent=2, ensure_ascii=False)


def error(msg: str) -> int:
    log(msg)
        print(msg, file=sys.stderr)
    try:
        import ctypes

        ctypes.windll.user32.MessageBoxW(0, msg, APP_DISPLAY_NAME, 0x10)
    except Exception:
        pass
    return 1


def client_credentials() -> Tuple[str, str]:
    env_id = os.environ.get("GOOGLE_CLIENT_ID")
    env_secret = os.environ.get("GOOGLE_CLIENT_SECRET")
    if env_id and env_secret:
        return env_id.strip(), env_secret.strip()

    if not CLIENT_SECRET_FILE.exists():
        raise RuntimeError(
            "Arquivo client_secret.json não encontrado.\n"
            "Crie um OAuth Client ID (Desktop) no Google Cloud e salve o json como client_secret.json "
            f"ao lado deste script ({CLIENT_SECRET_FILE}).\n"
            "Ou defina as variáveis GOOGLE_CLIENT_ID e GOOGLE_CLIENT_SECRET."
        )

    with CLIENT_SECRET_FILE.open("r", encoding="utf-8-sig") as f:
        data = json.load(f)

    for key in ("installed", "web"):
        block = data.get(key)
        if isinstance(block, dict):
            cid = block.get("client_id")
            secret = block.get("client_secret")
            if cid and secret:
                return cid, secret

    raise RuntimeError("client_secret.json sem campos client_id/client_secret.")


def build_url(params: Optional[Dict[str, str]] = None) -> str:
    if not params:
        return DRIVE_FILES_URL
    return DRIVE_FILES_URL + "?" + urllib.parse.urlencode(params)


def http_request_json(
    method: str,
    url: str,
    token: str,
    data: Optional[Any] = None,
    headers: Optional[Dict[str, str]] = None,
    timeout: int = 90,
) -> Dict[str, Any]:
    request_headers = {"Authorization": f"Bearer {token}"}
    if headers:
        request_headers.update(headers)

    payload: Optional[bytes] = None
    if data is not None:
        if isinstance(data, (bytes, bytearray)):
            payload = bytes(data)
            request_headers.setdefault("Content-Type", "application/octet-stream")
        else:
            payload = json.dumps(data).encode("utf-8")
            request_headers.setdefault("Content-Type", "application/json")

    request = urllib.request.Request(url, data=payload, method=method)
    for key, value in request_headers.items():
        request.add_header(key, value)

    try:
        with urllib.request.urlopen(request, timeout=timeout) as resp:
            raw = resp.read()
            if not raw:
                return {}
            text = raw.decode("utf-8")
            if not text.strip():
                return {}
            return json.loads(text)
    except HTTPError as exc:
        details = exc.read().decode("utf-8", errors="replace").strip()
        if details:
            raise RuntimeError(f"HTTP Error {exc.code}: {details}") from exc
        raise


def http_post_json(url: str, data: Dict[str, str], timeout: int = 60) -> Dict[str, Any]:
    payload = urllib.parse.urlencode(data).encode("utf-8")
    request = urllib.request.Request(url, data=payload, method="POST")
    request.add_header("Content-Type", "application/x-www-form-urlencoded")
    request.add_header("Accept", "application/json")
    try:
        with urllib.request.urlopen(request, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except HTTPError as exc:
        details = exc.read().decode("utf-8", errors="replace").strip()
        if details:
            raise RuntimeError(f"HTTP Error {exc.code}: {details}") from exc
        raise


def parse_drive_time(value: str) -> Optional[float]:
    if not value:
        return None
    if value.endswith("Z"):
        value = value[:-1] + "+00:00"
    try:
        return datetime.fromisoformat(value).timestamp()
    except Exception:
        return None


def drive_time_iso(ts: float) -> str:
    return datetime.fromtimestamp(ts, tz=timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def ensure_token(state: Dict[str, Any], client_id: str, client_secret: str) -> str:
    token = state.get("token") or {}
    now = time.time()
    if token.get("access_token") and token.get("expires_at", 0) - now > 120:
        return token["access_token"]

    if token.get("refresh_token"):
        try:
            refreshed = http_post_json(
                TOKEN_ENDPOINT,
                {
                    "client_id": client_id,
                    "client_secret": client_secret,
                    "refresh_token": token["refresh_token"],
                    "grant_type": "refresh_token",
                },
            )
            token.update(refreshed)
            token["expires_at"] = now + int(refreshed.get("expires_in", 3600))
            state["token"] = token
            save_state(state)
            return token["access_token"]
        except Exception:
            log("Falha ao atualizar token. Fazendo login novamente.")

    state_str = secrets.token_urlsafe(16)
    callback = {"code": None, "error": None}
    event = threading.Event()

    class CallbackHandler(BaseHTTPRequestHandler):
        def do_GET(self) -> None:
            parsed = urllib.parse.urlparse(self.path)
            query = urllib.parse.parse_qs(parsed.query)

            if query.get("state", [None])[0] != state_str:
                callback["error"] = "invalid_state"
                event.set()
            else:
                if "code" in query:
                    callback["code"] = query["code"][0]
                    self.send_response(200)
                    self.send_header("Content-Type", "text/html; charset=utf-8")
                    self.end_headers()
                    self.wfile.write(
                        b"<h1>Autenticacao concluida.</h1>"
                        b"<p>Volte para o terminal. O arquivo vai abrir em seguida.</p>"
                    )
                    event.set()
                elif "error" in query:
                    callback["error"] = query["error"][0]
                    self.send_response(400)
                    self.send_header("Content-Type", "text/html; charset=utf-8")
                    self.end_headers()
                    self.wfile.write(b"<h1>Erro de autenticacao.</h1>")
                    event.set()
                else:
                    self.send_response(400)
                    self.send_header("Content-Type", "text/html; charset=utf-8")
                    self.end_headers()
                    self.wfile.write(b"<h1>Resposta desconhecida.</h1>")

        def log_message(self, format: str, *args: Any) -> None:
            return

    httpd = HTTPServer(("127.0.0.1", 0), CallbackHandler)
    port = httpd.server_address[1]
    redirect_uri = f"http://127.0.0.1:{port}"

    auth_url = AUTH_ENDPOINT + "?" + urllib.parse.urlencode(
        {
            "client_id": client_id,
            "redirect_uri": redirect_uri,
            "response_type": "code",
            "scope": DRIVE_SCOPE,
            "access_type": "offline",
            "include_granted_scopes": "true",
            "prompt": "consent",
            "state": state_str,
        }
    )

    server_thread = threading.Thread(target=httpd.serve_forever, daemon=True)
    server_thread.start()
    webbrowser.open(auth_url, new=1, autoraise=True)

    ok = event.wait(180)
    httpd.shutdown()
    httpd.server_close()
    if not ok:
        raise TimeoutError("Tempo limite da autorização expirou.")
    if callback.get("error"):
        raise RuntimeError(f"Falha na autorização: {callback['error']}")

    code = callback.get("code")
    if not code:
        raise RuntimeError("Não recebeu código de autorização.")

    tokens = http_post_json(
        TOKEN_ENDPOINT,
        {
            "client_id": client_id,
            "client_secret": client_secret,
            "code": code,
            "grant_type": "authorization_code",
            "redirect_uri": redirect_uri,
        },
    )

    if "error" in tokens:
        raise RuntimeError(f"Erro no token: {tokens['error']}")

    tokens["expires_at"] = now + int(tokens.get("expires_in", 3600))
    state["token"] = tokens
    save_state(state)
    return tokens["access_token"]


def file_key(path: Path) -> str:
    normalized = str(path.resolve())
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def file_sha256(path: Path, chunk_size: int = 1024 * 1024) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as f:
        while True:
            chunk = f.read(chunk_size)
            if not chunk:
                break
            digest.update(chunk)
    return digest.hexdigest()


def safe_upload_filename(file_path: Path) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9._-]", "_", file_path.name)
    if not cleaned or cleaned in {".", ".."}:
        cleaned = f"upload{file_path.suffix.lower()}"
    return cleaned


def build_multipart(file_path: Path, target_mime: str, original_mime: str, folder_id: str) -> Tuple[bytes, str]:
    metadata = json.dumps({"name": file_path.name, "mimeType": target_mime, "parents": [folder_id]}).encode("utf-8")
    boundary = secrets.token_hex(16)
    separator = f"--{boundary}\r\n".encode("utf-8")
    ending = f"--{boundary}--\r\n".encode("utf-8")
    upload_name = safe_upload_filename(file_path)

    body = [
        separator,
        b"Content-Type: application/json; charset=UTF-8\r\n\r\n",
        metadata,
        b"\r\n",
        separator,
        f'Content-Type: {original_mime}\r\nContent-Disposition: form-data; name="file"; filename="{upload_name}"\r\n\r\n'.encode(
            "utf-8"
        ),
        file_path.read_bytes(),
        b"\r\n",
        ending,
    ]
    return b"".join(body), boundary


def get_file_metadata(token: str, file_id: str) -> Dict[str, Any]:
    return http_request_json(
        "GET",
        f"{DRIVE_FILES_URL}/{file_id}?" + urllib.parse.urlencode({"fields": "id,name,mimeType,trashed"}),
        token,
    )


def find_temp_folder(token: str, folder_name: str) -> Optional[str]:
    escaped_name = folder_name.replace("'", "\\'")
    query = (
        f"mimeType='{FOLDER_MIME}' and name='{escaped_name}' and 'root' in parents and trashed=false"
    )
    page_token = None
    while True:
        params: Dict[str, str] = {
            "q": query,
            "fields": "files(id,name,mimeType),nextPageToken",
            "pageSize": "100",
        }
        if page_token:
            params["pageToken"] = page_token
        response = http_request_json("GET", build_url(params), token)
        for item in response.get("files", []):
            if item.get("name") == folder_name and item.get("mimeType") == FOLDER_MIME:
                return item.get("id")
        page_token = response.get("nextPageToken")
        if not page_token:
            break
    return None


def ensure_temp_folder(token: str, state: Dict[str, Any], folder_name: str) -> str:
    settings = state.setdefault("settings", {})
    folder_id = settings.get("temp_folder_id")

    if folder_id:
        if FAST_OPEN:
            return folder_id
        try:
            metadata = get_file_metadata(token, folder_id)
            if metadata.get("mimeType") == FOLDER_MIME and not metadata.get("trashed"):
                return folder_id
        except Exception:
            folder_id = None

    folder_id = find_temp_folder(token, folder_name)
    if folder_id:
        settings["temp_folder_id"] = folder_id
        save_state(state)
        return folder_id

    created = http_request_json(
        "POST",
        build_url({"fields": "id"}),
        token,
        {"name": folder_name, "mimeType": FOLDER_MIME},
    )
    folder_id = created["id"]
    settings["temp_folder_id"] = folder_id
    save_state(state)
    return folder_id


def should_run_cleanup(state: Dict[str, Any], retention_hours: float) -> bool:
    if retention_hours <= 0:
        return False
    settings = state.setdefault("settings", {})
    now = time.time()
    last_cleanup = float(settings.get("last_cleanup_at", 0.0))
    interval = CLEANUP_MIN_INTERVAL_HOURS * 3600.0
    if now - last_cleanup < interval:
        return False
    settings["last_cleanup_at"] = now
    return True


def needs_upload_retry(exc: Exception, folder_id: str) -> bool:
    message = str(exc).lower()
    return "404" in message and (
        "file not found" in message
        or "not found" in message
        or "parent" in message
        or "invalid" in message
        or folder_id in message
    )


def upload_to_drive(
    access_token: str,
    file_path: Path,
    target_mime: str,
    folder_id: str,
    existing_id: Optional[str] = None,
) -> str:
    original_mime, _ = mimetypes.guess_type(file_path.name)
    if original_mime is None:
        original_mime = "application/octet-stream"

    body, boundary = build_multipart(file_path, target_mime, original_mime, folder_id)
    headers = {
        "Content-Type": f"multipart/related; boundary={boundary}",
    }

    if existing_id:
        url = f"{DRIVE_UPLOAD_URL}/{existing_id}?uploadType=multipart&fields=id,webViewLink,parents"
        response = http_request_json("PATCH", url, access_token, data=body, headers=headers)
    else:
        url = f"{DRIVE_UPLOAD_URL}?uploadType=multipart&fields=id,webViewLink"
        response = http_request_json("POST", url, access_token, data=body, headers=headers)

    return response["id"]


def delete_drive_file(token: str, file_id: str) -> None:
    try:
        http_request_json("DELETE", f"{DRIVE_FILES_URL}/{file_id}", token)
    except Exception:
        pass


def cleanup_temp_folder(token: str, folder_id: str, retention_hours: float, state: Dict[str, Any]) -> int:
    if retention_hours <= 0:
        return 0

    cutoff = time.time() - (retention_hours * 3600)
    cutoff_iso = drive_time_iso(cutoff)
    deleted_files = []
    query = f"'{folder_id}' in parents and trashed = false and createdTime < '{cutoff_iso}'"
    page_token = None

    while True:
        params: Dict[str, str] = {
            "q": query,
            "fields": "files(id,name),nextPageToken",
            "pageSize": "1000",
        }
        if page_token:
            params["pageToken"] = page_token
        response = http_request_json("GET", build_url(params), token)

        for item in response.get("files", []):
            file_id = item.get("id")
            if file_id:
                delete_drive_file(token, file_id)
                deleted_files.append(file_id)

        page_token = response.get("nextPageToken")
        if not page_token:
            break

    if deleted_files:
        files = state.setdefault("files", {})
        for key, info in list(files.items()):
            if info.get("file_id") in deleted_files:
                del files[key]
        save_state(state)

    return len(deleted_files)


def open_google_file(file_id: str, kind: str) -> None:
    if kind == "doc":
        url = f"https://docs.google.com/document/d/{file_id}/edit"
    elif kind == "sheet":
        url = f"https://docs.google.com/spreadsheets/d/{file_id}/edit"
    elif kind == "slide":
        url = f"https://docs.google.com/presentation/d/{file_id}/edit"
    else:
        raise ValueError(f"Tipo de abertura inválido: {kind}")
    webbrowser.open(url, new=2, autoraise=True)


def resolve_kind(path: Path, explicit_kind: Optional[str]) -> str:
    if explicit_kind:
        explicit_kind = explicit_kind.lower()
        if explicit_kind not in {"doc", "sheet", "slide"}:
            raise ValueError("Tipo explícito inválido. Use doc, sheet ou slide.")
        return explicit_kind

    ext = path.suffix.lower()
    if ext in DOC_EXTS:
        return "doc"
    if ext in SHEET_EXTS:
        return "sheet"
    if ext in SLIDE_EXTS:
        return "slide"
    raise ValueError("Formato não suportado. Use DOC/DOCX, XLS/XLSX ou PPT/PPTX.")


def main() -> int:
    parser = argparse.ArgumentParser(description="Abre documento local no Google Docs/Sheets/Slides.")
    parser.add_argument("file", nargs="?", help="Arquivo local para abrir.")
    parser.add_argument("--kind", required=False, help="doc|sheet|slide (opcional).")
    parser.add_argument("--no-cache", action="store_true", help="Sempre cria novo arquivo no Drive.")
    parser.add_argument("--temp-folder", default=TEMP_FOLDER_DEFAULT, help="Nome da pasta padrão no Google Drive.")
    parser.add_argument(
        "--retention-hours",
        type=float,
        default=float(DEFAULT_RETENTION_HOURS),
        help="Tempo em horas para manter os arquivos temporários (0 para nunca remover).",
    )
    parser.add_argument(
        "--no-cleanup",
        action="store_true",
        help="Desativa a limpeza automática de arquivos antigos da pasta temporária.",
    )
    args = parser.parse_args()

    if not args.file:
        return error("Informe o caminho do arquivo como argumento.")

    file_path = Path(args.file).expanduser()
    if not file_path.exists() or not file_path.is_file():
        return error(f"Arquivo não encontrado: {file_path}")

    try:
        kind = resolve_kind(file_path, args.kind)
    except ValueError as exc:
        return error(str(exc))

    try:
        client_id, client_secret = client_credentials()
        state = load_state()
        token = ensure_token(state, client_id, client_secret)

        target_mime = {
            "doc": "application/vnd.google-apps.document",
            "sheet": "application/vnd.google-apps.spreadsheet",
            "slide": "application/vnd.google-apps.presentation",
        }[kind]
        temp_folder_name = args.temp_folder.strip() or TEMP_FOLDER_DEFAULT
        temp_folder_id = ensure_temp_folder(token, state, temp_folder_name)
        if not args.no_cleanup and should_run_cleanup(state, args.retention_hours):
            removed = cleanup_temp_folder(token, temp_folder_id, args.retention_hours, state)
            if removed:
                log(f"Arquivos removidos da pasta temporária: {removed}")
            save_state(state)

        key = file_key(file_path.resolve())
        cached = state.get("files", {}).get(key, {})
        current_mtime = int(file_path.stat().st_mtime)
        current_size = file_path.stat().st_size
        current_hash: Optional[str] = cached.get("sha256")
        cached_hash = cached.get("sha256")
        existing = cached.get("file_id") if not args.no_cache else None
        file_id: Optional[str] = None

        if existing and cached.get("kind") == kind and cached.get("temp_folder_id") == temp_folder_id and not args.no_cache:
            try:
                previous_mtime = int(cached.get("mtime", -1))
                previous_size = int(cached.get("size", -1))
                if current_mtime != previous_mtime or current_size != previous_size:
                    if cached_hash is not None:
                        current_hash = file_sha256(file_path)
                        if cached_hash == current_hash:
                            file_id = existing
                        else:
                            file_id = upload_to_drive(
                                token,
                                file_path,
                                target_mime,
                                temp_folder_id,
                                existing_id=existing,
                            )
                    else:
                        file_id = upload_to_drive(
                            token,
                            file_path,
                            target_mime,
                            temp_folder_id,
                            existing_id=existing,
                        )
                else:
                    file_id = existing
                    if cached_hash is None:
                        current_hash = file_sha256(file_path)
            except Exception:
                existing = None

        if not file_id:
            try:
                if current_hash is None and not args.no_cache:
                    current_hash = file_sha256(file_path)
                file_id = upload_to_drive(token, file_path, target_mime, temp_folder_id, existing_id=None)
            except Exception as exc:
                if not needs_upload_retry(exc, temp_folder_id):
                    raise
                temp_folder_id = ensure_temp_folder(token, state, temp_folder_name)
                file_id = upload_to_drive(token, file_path, target_mime, temp_folder_id, existing_id=None)

        if not args.no_cache:
            state["files"][key] = {
                "file_id": file_id,
                "kind": kind,
                "mtime": current_mtime,
                "size": current_size,
                "name": file_path.name,
                "path": str(file_path),
                "temp_folder_id": temp_folder_id,
                "sha256": current_hash,
            }
        save_state(state)

        open_google_file(file_id, kind)
        return 0
    except Exception as exc:
        return error(f"Erro: {exc}")


if __name__ == "__main__":
    sys.exit(main())
