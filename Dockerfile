# syntax=docker/dockerfile:1

FROM node:22-bookworm AS builder
WORKDIR /app

# вместо corepack
RUN npm i -g pnpm@10.12.1

# Отключаем хуки/prepare в CI/контейнере
ENV CI=true
ENV HUSKY=0

ENV NODE_OPTIONS=--max-old-space-size=8192
COPY . .

# Ставим зависимости без запуска пост-инсталляционных "проверок" хуков
RUN pnpm --version
RUN pnpm install --frozen-lockfile --reporter=append-only
RUN pnpm build

FROM node:22-bookworm AS runtime
WORKDIR /app

RUN npm i -g pnpm@10.12.1

# создаём пользователя
RUN useradd -ms /bin/bash nodeuser

# копируем приложение
COPY --from=builder /app /app

# папка для n8n данных + права
RUN mkdir -p /home/nodeuser/.n8n \
  && chown -R nodeuser:nodeuser /home/nodeuser

ENV NODE_ENV=production
ENV N8N_USER_FOLDER=/home/nodeuser/.n8n
EXPOSE 5678

# стартуем root'ом, чиним volume, потом запускаем как nodeuser
ENTRYPOINT ["bash", "-lc", "chown -R nodeuser:nodeuser /home/nodeuser/.n8n && su -s /bin/bash nodeuser -c 'cd /app/packages/cli && pnpm start'"]