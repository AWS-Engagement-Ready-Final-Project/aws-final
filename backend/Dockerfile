# Use aws public image
FROM public.ecr.aws/docker/library/node:24.2.0-slim
# Copy application code.
COPY . /app/
# Change the working directory
WORKDIR /app
# Install dependencies.
RUN npm install
# Start the Express app
CMD ["node", "server.js"]
