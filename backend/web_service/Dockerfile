FROM python:3.12-slim
WORKDIR /app
COPY backend /app/backend
COPY 3d_game/assets/materials/palette.json /app/3d_game/assets/materials/palette.json
RUN useradd --create-home game && mkdir -p /data && chown game:game /data
USER game
RUN PYTHONPATH=/app/backend python -c "from web_service.server import Application"
ENV PYTHONUNBUFFERED=1 WEB_DATA_DIR=/data/web PORT=8080
EXPOSE 8080
CMD ["python", "backend/web_service/server.py"]
