from app.database import engine, Base
from app.models import plant, user, plant_state, disease_record, reminder, plant_log

def reset_db():
    print("Dropping and recreating all tables...")
    try:
        # Drop all tables to clear existing schema
        Base.metadata.drop_all(bind=engine)
        # Recreate all tables with updated schema
        Base.metadata.create_all(bind=engine)
        print("Database schema reset and recreated successfully.")
    except Exception as e:
        print(f"Error resetting database: {e}")

if __name__ == "__main__":
    reset_db()
