"""Email жіберу (стандартты smtplib, қосымша кітапхана қажет емес).

.env-те MAIL_SERVER бос болса — хат жіберілмейді, оның мәтіні сервер терминалына шығады
(әзірлеу режимі: қалпына келтіру сілтемесін сол жерден көшіруге болады).
"""

from __future__ import annotations

import re
import smtplib
import ssl
import sys
import threading
from email.message import EmailMessage

from flask import current_app


def _deliver(config: dict, to: str, subject: str, text: str) -> None:
    msg = EmailMessage()
    msg["From"] = config.get("MAIL_FROM") or config.get("MAIL_USERNAME")
    msg["To"] = to
    msg["Subject"] = subject
    msg.set_content(text)

    host = config["MAIL_SERVER"]
    port = int(config.get("MAIL_PORT") or 587)
    context = ssl.create_default_context()
    if port == 465:
        server = smtplib.SMTP_SSL(host, port, context=context, timeout=15)
    else:
        server = smtplib.SMTP(host, port, timeout=15)
        server.starttls(context=context)
    with server:
        if config.get("MAIL_USERNAME"):
            server.login(config["MAIL_USERNAME"], config.get("MAIL_PASSWORD", ""))
        server.send_message(msg)


def _console(text: str) -> None:
    """Терминалға шығару. Windows консолі cp1251 болса, қазақ әріптері (ә, ү, ұ…) кодталмай қатеге
    әкелмесін — сыймаған таңбалар «?» болады, сілтеме (ASCII) бәрібір дұрыс көрінеді."""
    try:
        print(text, flush=True)
    except UnicodeEncodeError:
        enc = getattr(sys.stdout, "encoding", None) or "ascii"
        print(text.encode(enc, errors="replace").decode(enc, errors="replace"), flush=True)


def send_mail(to: str, subject: str, text: str) -> None:
    """Хатты жібереді. Әдепкіде фондық ағында — жауап уақыты бойынша «бұл email тіркелген бе»
    деген ақпарат сыртқа шықпауы үшін (OWASP: account enumeration)."""
    app = current_app._get_current_object()
    config = {k: app.config.get(k) for k in ("MAIL_SERVER", "MAIL_PORT", "MAIL_USERNAME", "MAIL_PASSWORD", "MAIL_FROM")}

    if not config["MAIL_SERVER"]:
        # Әзірлеу режимі: хат жіберілмейді, мәтіні терминалға шығады. Сілтемелер бөлек ASCII жолмен.
        links = "\n".join(f"LINK: {url}" for url in re.findall(r"https?://\S+", text))
        _console(f"\n===== EMAIL (MAIL_SERVER is not set, not sent) -> {to}\n{links}\n\n"
                 f"Тақырып: {subject}\n\n{text}\n=====\n")
        return

    def run() -> None:
        try:
            _deliver(config, to, subject, text)
        except (smtplib.SMTPException, OSError):
            app.logger.exception("Хат жіберілмеді (%s)", to)

    if app.config.get("MAIL_ASYNC", True):
        threading.Thread(target=run, daemon=True).start()
    else:
        run()
