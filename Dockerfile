FROM tiangolo/uwsgi-nginx-flask:python3.8

# Set working dir for requirements
WORKDIR /pysetup

# Install system dependencies required by psycopg2-binary and others
USER root
RUN apt-get update && apt-get install -y gcc libpq-dev && rm -rf /var/lib/apt/lists/*

# Copy and install Python dependencies
COPY ./app/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Create necessary folders
RUN mkdir -p /app/screenshots

# Switch to app directory
WORKDIR /app

# Copy app code
COPY ./app/ /app/

# Fix permissions (especially if using a non-root user later)
RUN chown -R www-data:www-data /app/screenshots

# Keep using default CMD from base image
