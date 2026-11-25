"""Әзірлеу серверін іске қосу: python run.py  →  http://127.0.0.1:5000

Іске қосылғанда db/schema.sql орындалады (кестелер жоқ болса жасалады).
"""

import os

from app import create_app
from app.db import init_schema

app = create_app()

if __name__ == "__main__":
    with app.app_context():
        init_schema()
    app.run(
        host="127.0.0.1",
        port=int(os.environ.get("PORT", "5000")),
        debug=os.environ.get("FLASK_DEBUG") == "1",
    )
