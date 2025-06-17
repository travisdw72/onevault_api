import os
from dotenv import load_dotenv

load_dotenv()

print("Environment variables:")
print(f"DB_HOST: {os.getenv('DB_HOST')}")
print(f"DB_PORT: {os.getenv('DB_PORT')}")
print(f"DB_ADMIN_USER: {os.getenv('DB_ADMIN_USER')}")
print(f"DB_ADMIN_PASSWORD: {os.getenv('DB_ADMIN_PASSWORD')}") 