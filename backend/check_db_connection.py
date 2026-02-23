from sqlalchemy import create_engine, text
from app.config import settings
import sys

try:
    print(f"Testing connection to: {settings.DATABASE_URL.split('@')[1] if '@' in settings.DATABASE_URL else 'Local DB'}")
    engine = create_engine(settings.DATABASE_URL)
    with engine.connect() as connection:
        result = connection.execute(text("SELECT 1"))
        print("\n✅ Successfully connected to the database!")
except Exception as e:
    print(f"\n❌ Connection failed: {e}")
    sys.exit(1)
