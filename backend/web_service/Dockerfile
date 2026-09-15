FROM python:3.12-slim
WORKDIR /app
COPY backend /app/backend
RUN useradd --create-home game && mkdir -p /data && chown game:game /data
USER game
ENV PYTHONUNBUFFERED=1 WEB_DATA_DIR=/data/web PORT=8080
EXPOSE 8080
CMD ["python", "backend/web_service/server.py"]
