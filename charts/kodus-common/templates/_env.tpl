{{/*
Database connection env vars. Per store, one of three modes:
  bundled  → the StatefulSet + Secret this chart creates
  external → user-provided values + existingSecret
  operator → the operator-created Service + Secret
Call with root ctx.
*/}}
{{- define "kodus-common.dbEnv" -}}
{{/* ---- Postgres ---- */}}
{{- if eq .Values.postgres.mode "bundled" }}
- name: API_PG_DB_HOST
  value: {{ printf "%s-postgres" .Release.Name | quote }}
- name: API_PG_DB_PORT
  value: "5432"
- name: API_PG_DB_USERNAME
  value: {{ .Values.postgres.bundled.username | quote }}
- name: API_PG_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s-postgres-secret" .Release.Name }}
      key: password
- name: API_PG_DB_DATABASE
  value: {{ .Values.postgres.bundled.database | quote }}
{{- else if eq .Values.postgres.mode "operator" }}
- name: API_PG_DB_HOST
  value: {{ printf "%s-postgres-rw" .Release.Name | quote }}
- name: API_PG_DB_PORT
  value: "5432"
- name: API_PG_DB_USERNAME
  value: {{ .Values.postgres.operator.owner | quote }}
- name: API_PG_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s-postgres-app" .Release.Name }}
      key: password
- name: API_PG_DB_DATABASE
  value: {{ .Values.postgres.operator.database | quote }}
{{- else }}
- name: API_PG_DB_HOST
  value: {{ .Values.postgres.external.host | quote }}
- name: API_PG_DB_PORT
  value: {{ .Values.postgres.external.port | default 5432 | quote }}
- name: API_PG_DB_USERNAME
  value: {{ .Values.postgres.external.username | quote }}
- name: API_PG_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ required "postgres.external.existingSecret is required when postgres.mode=external" .Values.postgres.external.existingSecret }}
      key: {{ .Values.postgres.external.passwordKey | default "password" }}
- name: API_PG_DB_DATABASE
  value: {{ .Values.postgres.external.database | quote }}
{{- end }}
{{/* ---- Mongo ---- */}}
{{- if eq .Values.mongodb.mode "bundled" }}
- name: API_MG_DB_HOST
  value: {{ printf "%s-mongodb" .Release.Name | quote }}
- name: API_MG_DB_PORT
  value: "27017"
- name: API_MG_DB_USERNAME
  value: {{ .Values.mongodb.bundled.username | quote }}
- name: API_MG_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s-mongodb-secret" .Release.Name }}
      key: password
- name: API_MG_DB_DATABASE
  value: {{ .Values.mongodb.bundled.database | quote }}
{{- else if eq .Values.mongodb.mode "operator" }}
- name: API_MG_DB_HOST
  value: {{ printf "%s-mongodb-svc" .Release.Name | quote }}
- name: API_MG_DB_PORT
  value: "27017"
- name: API_MG_DB_USERNAME
  value: {{ .Values.mongodb.operator.username | quote }}
- name: API_MG_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s-mongodb-password" .Release.Name }}
      key: password
- name: API_MG_DB_DATABASE
  value: {{ .Values.mongodb.operator.database | quote }}
{{- else }}
- name: API_MG_DB_HOST
  value: {{ .Values.mongodb.external.host | quote }}
- name: API_MG_DB_PORT
  value: {{ .Values.mongodb.external.port | default 27017 | quote }}
- name: API_MG_DB_USERNAME
  value: {{ .Values.mongodb.external.username | quote }}
- name: API_MG_DB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ required "mongodb.external.existingSecret is required when mongodb.mode=external" .Values.mongodb.external.existingSecret }}
      key: {{ .Values.mongodb.external.passwordKey | default "password" }}
- name: API_MG_DB_DATABASE
  value: {{ .Values.mongodb.external.database | quote }}
{{- end }}
{{- end }}

{{/*
RabbitMQ connection env vars. Credentials are built in the pod env via $(VAR)
refs (k8s resolves $(VAR) only inside the pod env block). Vhost is kodus-ai.
*/}}
{{- define "kodus-common.rabbitmqEnv" -}}
{{- if eq .Values.rabbitmq.mode "bundled" }}
- name: RABBITMQ_USER
  value: {{ .Values.rabbitmq.bundled.username | quote }}
- name: RABBITMQ_PASS
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s-rabbitmq-secret" .Release.Name }}
      key: password
- name: API_RABBITMQ_URI
  value: "amqp://$(RABBITMQ_USER):$(RABBITMQ_PASS)@{{ .Release.Name }}-rabbitmq:5672/kodus-ai"
{{- else if eq .Values.rabbitmq.mode "operator" }}
- name: RABBITMQ_USER
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s-rabbitmq-default-user" .Release.Name }}
      key: username
- name: RABBITMQ_PASS
  valueFrom:
    secretKeyRef:
      name: {{ printf "%s-rabbitmq-default-user" .Release.Name }}
      key: password
- name: API_RABBITMQ_URI
  value: "amqp://$(RABBITMQ_USER):$(RABBITMQ_PASS)@{{ .Release.Name }}-rabbitmq:5672/kodus-ai"
{{- else }}
- name: API_RABBITMQ_URI
  valueFrom:
    secretKeyRef:
      name: {{ required "rabbitmq.external.existingSecret is required when rabbitmq.mode=external" .Values.rabbitmq.external.existingSecret }}
      key: {{ .Values.rabbitmq.external.uriKey | default "uri" }}
{{- end }}
{{- end }}

{{/*
App secrets env vars — from existingSecret or the chart-generated Secret.
REQUIRED secrets are non-optional: the pod fails to start if the key is missing,
a deliberate guard against booting with empty auth/crypto secrets. Note the
underscore in API_JWT_REFRESH_SECRET (API_JWT_REFRESHSECRET is a legacy typo no
longer read by code), and NEXTAUTH_SECRET is distinct from WEB_NEXTAUTH_SECRET
(both required, mirrored to the same value).
OPTIONAL secrets (LLM keys, MCP manager, webhook token) stay optional so a minimal
install boots without them.
NOTE for self-hosted Claude/Anthropic users: the Anthropic key goes into
API_OPEN_AI_API_KEY (kodus-ai reads the single LLM key from that slot and selects
the SDK by model-id prefix).
*/}}
{{- define "kodus-common.appSecretsEnv" -}}
{{- $secretName := default (printf "%s-secrets" .Release.Name) .Values.global.existingSecret -}}
{{- range $key := list "API_JWT_SECRET" "API_JWT_REFRESH_SECRET" "WEB_NEXTAUTH_SECRET" "NEXTAUTH_SECRET" "API_CRYPTO_KEY" "CODE_MANAGEMENT_SECRET" }}
- name: {{ $key }}
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: {{ $key }}
{{- end }}
{{- range $key := list "CODE_MANAGEMENT_WEBHOOK_TOKEN" "API_OPEN_AI_API_KEY" "API_MORPHLLM_API_KEY" "API_E2B_KEY" "API_MCP_MANAGER_JWT_SECRET" "API_MCP_MANAGER_ENCRYPTION_SECRET" }}
- name: {{ $key }}
  valueFrom:
    secretKeyRef:
      name: {{ $secretName }}
      key: {{ $key }}
      optional: true
{{- end }}
{{- end }}

{{/*
GitHub App credentials, keyed by the githubApp.<field> each is read from. Shared by
the env block below and the kodus chart's validator, so the two cannot disagree.
*/}}
{{- define "kodus-common.githubAppFields" -}}
appId: API_GITHUB_APP_ID
clientId: GLOBAL_GITHUB_CLIENT_ID
clientSecret: API_GITHUB_CLIENT_SECRET
privateKey: API_GITHUB_PRIVATE_KEY
{{- end }}

{{/*
GitHub App env vars — each a secretKeyRef built from githubApp.<field>.{name,key},
never a literal value. A field with an empty name is skipped (no GitHub App, or
OAuth-only). A referenced key is NOT optional: a typo'd key fails the pod at start
instead of surfacing later as "GitHub App is not configured" on the first
installation-token request. Call with root ctx.
*/}}
{{- define "kodus-common.githubAppEnv" -}}
{{- $refs := .Values.githubApp | default dict }}
{{- range $field, $env := (include "kodus-common.githubAppFields" . | fromYaml) }}
{{- $ref := index $refs $field | default dict }}
{{- if $ref.name }}
- name: {{ $env }}
  valueFrom:
    secretKeyRef:
      name: {{ $ref.name }}
      key: {{ required (printf "githubApp.%s.key is required when githubApp.%s.name is set" $field $field) $ref.key }}
{{- end }}
{{- end }}
{{- end }}
