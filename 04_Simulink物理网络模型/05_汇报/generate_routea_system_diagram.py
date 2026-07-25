"""Generate the Route A system-architecture illustration through DuckCoding.

The script records only prompt and response metadata. It reads the image proxy
credentials from the existing user-level environment variables and never writes
their values to disk.
"""

import base64
import json
import os
import sys
import time
from pathlib import Path

import requests
from PIL import Image


REPORT_DIR = Path(__file__).resolve().parent
ASSET_DIR = REPORT_DIR / "assets"
OUTPUT_PATH = ASSET_DIR / "routea_cegr_pemfc_system_architecture_v01.png"
SUMMARY_PATH = ASSET_DIR / "routea_cegr_pemfc_system_architecture_v01.json"

PROMPT = """Use case: scientific-educational
Asset type: PowerPoint system architecture illustration

Primary request:
Create a clean, professional engineering systems schematic of an integrated
cathode exhaust gas recirculation PEM fuel-cell system. A Simulink top-level
model is only an architecture reference; do not reproduce a software interface,
blocks, wires, or labels.

Scene/backdrop:
Pure white or very light neutral background, suitable for a technical
management presentation.

Subject and flow:
Place a PEM fuel-cell stack at the center as the system anchor.
Show a blue cathode air path: ambient air -> compressor -> intercooler ->
humidifier and mixer -> cathode inlet of the stack.
Show a blue cathode exhaust path: stack cathode outlet -> exhaust splitter.
One branch exits through a back-pressure control element. The other branch is
a clearly visible cathode exhaust gas recirculation loop: exhaust -> water
separation icon -> controllable cEGR valve -> return to the upstream mixer
before the compressor.
Show a restrained red hydrogen path: hydrogen supply -> anode conditioning and
recirculation unit -> stack anode -> purge or recirculation return.
Show a teal thermal-management loop: stack cooling ports -> coolant pump and
radiator -> stack cooling ports.
Show a yellow electrical path: stack electrical output -> controlled electrical
load and performance measurement.
Show a small gray supervisory controller connected with thin dashed
command/measurement lines to the compressor, cEGR valve, back-pressure
control, humidifier, cooling loop, and electrical load.

Style/medium:
High-end scientific and engineering infographic, physically plausible equipment
icons, clean vector-like 3D hybrid illustration, not photorealistic, not a
software screenshot.

Composition/framing:
Balanced square composition with generous whitespace around the modules for
later PowerPoint labels. Make the cEGR loop visually prominent but keep the
fuel-cell stack as the largest central object. Use clear directional arrows and
avoid crossing pipes where possible.

Color palette:
Blue for cathode air and cEGR, restrained red for hydrogen, teal for coolant,
yellow for electricity, gray for control signals, and dark graphite for the
stack. Use restrained professional colors, no gradients, no decorative
background elements.

Text:
No readable text, no equations, no numbers, no logos, no watermark. Leave
clean blank spaces near the main modules for manual Chinese labels in
PowerPoint.

Constraints:
Technically plausible PEMFC system architecture. Do not show vehicles, people,
flames, clouds, fantasy equipment, excessive sensors, or detailed internal
stack chemistry. Do not imply that compressor efficiency, water-separation
efficiency, DCDC hardware, or other unverified component capabilities have
already been validated.
"""


def user_env(name: str) -> str:
    value = os.environ.get(name)
    if value:
        return value
    if os.name == "nt":
        import winreg

        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as key:
                return winreg.QueryValueEx(key, name)[0]
        except OSError:
            return ""
    return ""


def system_proxy_url() -> str:
    override = os.environ.get("GPT_IMAGE_HTTP_PROXY", "").strip()
    if override:
        return override
    if os.name != "nt":
        return ""

    import winreg

    try:
        with winreg.OpenKey(
            winreg.HKEY_CURRENT_USER,
            r"Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings",
        ) as key:
            enabled = winreg.QueryValueEx(key, "ProxyEnable")[0]
            server = winreg.QueryValueEx(key, "ProxyServer")[0]
    except OSError:
        return ""
    if not enabled or not server:
        return ""
    server = str(server).split(";")[0]
    if "=" in server:
        server = server.split("=", 1)[1]
    return "http://" + server


def decode_image(data: dict, session: requests.Session) -> bytes:
    if data.get("b64_json"):
        return base64.b64decode(data["b64_json"])
    if data.get("url"):
        response = session.get(data["url"], timeout=120)
        response.raise_for_status()
        return response.content
    raise RuntimeError("Image response contains neither b64_json nor url.")


def image_info(path: Path) -> dict:
    with Image.open(path) as image:
        return {
            "format": image.format,
            "mode": image.mode,
            "width": image.width,
            "height": image.height,
            "bytes": path.stat().st_size,
        }


def main() -> int:
    base_url = user_env("GPT_IMAGE_PROXY_BASE_URL").strip()
    key = user_env("GPT_IMAGE_PROXY_KEY").strip()
    if not base_url or not key:
        print("Missing GPT_IMAGE_PROXY_BASE_URL or GPT_IMAGE_PROXY_KEY.", file=sys.stderr)
        return 2

    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    proxy_url = system_proxy_url()
    session = requests.Session()
    session.trust_env = False
    if proxy_url:
        session.proxies.update({"http": proxy_url, "https": proxy_url})
    body = {
        "model": "gpt-image-2",
        "prompt": PROMPT,
        "size": "2048x2048",
        "quality": "high",
        "n": 1,
    }
    started = time.perf_counter()
    response = session.post(
        base_url.rstrip("/") + "/images/generations",
        headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
        json=body,
        timeout=600,
    )
    status_code = response.status_code
    raw_payload = response.content
    elapsed_s = round(time.perf_counter() - started, 2)
    try:
        payload = json.loads(raw_payload.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        print(raw_payload[:1000].decode("utf-8", errors="replace"), file=sys.stderr)
        return 3
    if status_code >= 400:
        print(json.dumps(payload, ensure_ascii=False)[:1200], file=sys.stderr)
        return 4

    data = payload.get("data") or []
    if not data:
        print("Response contains no image data.", file=sys.stderr)
        return 5

    OUTPUT_PATH.write_bytes(decode_image(data[0], session))
    summary = {
        "output_file": str(OUTPUT_PATH),
        "summary_file": str(SUMMARY_PATH),
        "http_status": status_code,
        "elapsed_s": elapsed_s,
        "proxy_enabled": bool(proxy_url),
        "request": body,
        "response_keys": sorted(payload.keys()),
        "data0_keys": sorted(data[0].keys()),
        "image": image_info(OUTPUT_PATH),
    }
    SUMMARY_PATH.write_text(
        json.dumps(summary, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
