from app.main import app

# Vercel handler
def handler(request, context):
    return app(request, context)

# For direct import
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000) 