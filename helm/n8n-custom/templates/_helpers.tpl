{{/*
Expand the name of the chart.
*/}}
{{- define "n8n-custom.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "n8n-custom.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "n8n-custom.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "n8n-custom.labels" -}}
helm.sh/chart: {{ include "n8n-custom.chart" . }}
{{ include "n8n-custom.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "n8n-custom.selectorLabels" -}}
app.kubernetes.io/name: {{ include "n8n-custom.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app: n8n
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "n8n-custom.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "n8n-custom.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return the proper image name
*/}}
{{- define "n8n-custom.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion -}}
{{- printf "%s:%s" .Values.image.repository $tag -}}
{{- end }}

{{/*
Return the database type environment variables
*/}}
{{- define "n8n-custom.databaseEnv" -}}
{{- if eq .Values.database.type "postgres" }}
- name: DB_TYPE
  value: "postgresdb"
- name: DB_POSTGRESDB_HOST
  value: {{ .Values.database.postgres.host | quote }}
- name: DB_POSTGRESDB_PORT
  value: {{ .Values.database.postgres.port | quote }}
- name: DB_POSTGRESDB_DATABASE
  value: {{ .Values.database.postgres.database | quote }}
- name: DB_POSTGRESDB_USER
  value: {{ .Values.database.postgres.user | quote }}
{{- if .Values.database.postgres.existingSecret }}
- name: DB_POSTGRESDB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.database.postgres.existingSecret }}
      key: {{ .Values.database.postgres.passwordKey }}
{{- else if .Values.database.postgres.password }}
- name: DB_POSTGRESDB_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "n8n-custom.fullname" . }}-secrets
      key: db-password
{{- end }}
{{- if .Values.database.postgres.ssl }}
- name: DB_POSTGRESDB_SSL_ENABLED
  value: "true"
{{- end }}
{{- else }}
- name: DB_TYPE
  value: "sqlite"
- name: DB_SQLITE_DATABASE
  value: {{ .Values.database.sqlite.path | quote }}
{{- end }}
{{- end }}

{{/*
Return encryption key environment variable
*/}}
{{- define "n8n-custom.encryptionEnv" -}}
{{- if .Values.encryption.existingSecret }}
- name: N8N_ENCRYPTION_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.encryption.existingSecret }}
      key: {{ .Values.encryption.secretKey }}
{{- else }}
- name: N8N_ENCRYPTION_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "n8n-custom.fullname" . }}-secrets
      key: encryption-key
{{- end }}
{{- end }}

{{/*
Return license environment variables
*/}}
{{- define "n8n-custom.licenseEnv" -}}
- name: N8N_LICENSE_SERVICE_ENABLED
  value: {{ .Values.license.serviceEnabled | quote }}
- name: N8N_LICENSE_OFFLINE_MODE
  value: {{ .Values.license.offlineMode | quote }}
- name: N8N_LICENSE_AUTO_RENEW_ENABLED
  value: {{ .Values.license.autoRenewEnabled | quote }}
{{- if .Values.license.existingSecret }}
{{- if .Values.license.activationKey }}
- name: N8N_LICENSE_ACTIVATION_KEY
  valueFrom:
    secretKeyRef:
      name: {{ .Values.license.existingSecret }}
      key: {{ .Values.license.activationKeyKey }}
{{- end }}
{{- if .Values.license.certificate }}
- name: N8N_LICENSE_CERT
  valueFrom:
    secretKeyRef:
      name: {{ .Values.license.existingSecret }}
      key: {{ .Values.license.certificateKey }}
{{- end }}
{{- else }}
{{- if .Values.license.activationKey }}
- name: N8N_LICENSE_ACTIVATION_KEY
  valueFrom:
    secretKeyRef:
      name: {{ include "n8n-custom.fullname" . }}-secrets
      key: license-activation-key
{{- end }}
{{- if .Values.license.certificate }}
- name: N8N_LICENSE_CERT
  valueFrom:
    secretKeyRef:
      name: {{ include "n8n-custom.fullname" . }}-secrets
      key: license-certificate
{{- end }}
{{- end }}
{{- if .Values.license.gdprOverrides.enabled }}
{{- if .Values.license.gdprOverrides.forcePlan }}
- name: N8N_LICENSE_FORCE_PLAN
  value: {{ .Values.license.gdprOverrides.forcePlan | quote }}
{{- end }}
{{- if .Values.license.gdprOverrides.forceFeatures }}
- name: N8N_LICENSE_FORCE_FEATURES
  value: {{ .Values.license.gdprOverrides.forceFeatures | quote }}
{{- end }}
{{- if .Values.license.gdprOverrides.blockFeatures }}
- name: N8N_LICENSE_BLOCK_FEATURES
  value: {{ .Values.license.gdprOverrides.blockFeatures | quote }}
{{- end }}
{{- range $key, $value := .Values.license.gdprOverrides.quotas }}
- name: N8N_LICENSE_QUOTA_{{ $key | upper | replace "-" "_" }}
  value: {{ $value | quote }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Return privacy environment variables
*/}}
{{- define "n8n-custom.privacyEnv" -}}
- name: N8N_DISABLE_EXTERNAL_COMMUNICATIONS
  value: {{ .Values.privacy.disableExternalCommunications | quote }}
- name: N8N_DIAGNOSTICS_ENABLED
  value: {{ not .Values.privacy.disableDiagnostics | quote }}
- name: N8N_VERSION_NOTIFICATIONS_ENABLED
  value: {{ not .Values.privacy.disableVersionNotifications | quote }}
- name: N8N_TEMPLATES_ENABLED
  value: {{ not .Values.privacy.disableTemplates | quote }}
- name: N8N_PERSONALIZATION_ENABLED
  value: {{ not .Values.privacy.disablePersonalization | quote }}
- name: N8N_AI_ENABLED
  value: {{ not .Values.privacy.disableAI | quote }}
- name: N8N_HIRING_BANNER_ENABLED
  value: {{ not .Values.privacy.disableHiringBanner | quote }}
- name: N8N_ONBOARDING_FLOW_DISABLED
  value: {{ .Values.privacy.disableOnboarding | quote }}
{{- end }}

{{/*
Return queue mode environment variables
*/}}
{{- define "n8n-custom.queueEnv" -}}
{{- if .Values.queue.enabled }}
- name: EXECUTIONS_MODE
  value: "queue"
- name: QUEUE_HEALTH_CHECK_ACTIVE
  value: "true"
- name: QUEUE_HEALTH_CHECK_INTERVAL
  value: {{ .Values.queue.healthCheckInterval | quote }}
- name: QUEUE_BULL_REDIS_HOST
  value: {{ .Values.queue.redis.host | quote }}
- name: QUEUE_BULL_REDIS_PORT
  value: {{ .Values.queue.redis.port | quote }}
{{- if .Values.queue.redis.existingSecret }}
- name: QUEUE_BULL_REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ .Values.queue.redis.existingSecret }}
      key: {{ .Values.queue.redis.passwordKey }}
{{- else if .Values.queue.redis.password }}
- name: QUEUE_BULL_REDIS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: {{ include "n8n-custom.fullname" . }}-secrets
      key: redis-password
{{- end }}
{{- end }}
{{- end }}

{{/*
Return SMTP environment variables
*/}}
{{- define "n8n-custom.smtpEnv" -}}
{{- if .Values.smtp.enabled }}
- name: N8N_EMAIL_MODE
  value: "smtp"
- name: N8N_SMTP_HOST
  value: {{ .Values.smtp.host | quote }}
- name: N8N_SMTP_PORT
  value: {{ .Values.smtp.port | quote }}
- name: N8N_SMTP_USER
  value: {{ .Values.smtp.user | quote }}
{{- if .Values.smtp.existingSecret }}
- name: N8N_SMTP_PASS
  valueFrom:
    secretKeyRef:
      name: {{ .Values.smtp.existingSecret }}
      key: {{ .Values.smtp.passwordKey }}
{{- else if .Values.smtp.password }}
- name: N8N_SMTP_PASS
  valueFrom:
    secretKeyRef:
      name: {{ include "n8n-custom.fullname" . }}-secrets
      key: smtp-password
{{- end }}
- name: N8N_SMTP_SENDER
  value: {{ .Values.smtp.sender | quote }}
- name: N8N_SMTP_SSL
  value: {{ .Values.smtp.ssl | quote }}
{{- end }}
{{- end }}
