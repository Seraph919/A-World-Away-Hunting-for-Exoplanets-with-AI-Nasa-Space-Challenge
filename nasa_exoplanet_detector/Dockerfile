# Use a lightweight Python image
FROM python:3.11-slim

# Avoid .pyc files + enable unbuffered output
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Install system dependencies for psycopg2, mysqlclient, lxml, cryptography
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    libmysqlclient-dev \
    libxml2-dev \
    libxslt1-dev \
    libssl-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Upgrade pip
RUN pip install --upgrade pip setuptools wheel

# Copy requirements and install Python deps
COPY requirements.txt .
RUN pip install -r requirements.txt

# Copy project files
COPY . .

# Expose Django’s default port
EXPOSE 8000

# Default command (you can override later if needed)
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
