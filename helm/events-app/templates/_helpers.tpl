{{/*
Expand the name of the chart.
*/}}
{{- define "events-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "events-app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- print $name }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "events-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "events-app.labels" -}}
helm.sh/chart: {{ include "events-app.chart" . }}
{{ include "events-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "events-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "events-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "events-app.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "events-app.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Helper to create an arbitrary service
*/}}
{{- define "events-app.service" -}}
{{- $fullname := include "events-app.fullname" .Globals }}
{{- $appName := print $fullname "-"  .name }}
{{- $name := print $appName "-svc" }}
apiVersion: v1
kind: Service
metadata:
  name: {{ $name }}
  labels:
    app: {{ $name }}
spec:
  type: {{ .type }}
  ports:
    - port: {{ .port }}
      targetPort: {{ .targetPort | default .port}}
      protocol: TCP
  selector:
    app: {{ $appName }} 
    ver: "{{ .ver }}"
{{- end }}

{{/*
Helper to create an arbitrary deployment
*/}}
{{- define "events-app.deployment" -}}
{{ $fullname := include "events-app.fullname" .Globals }}
{{ $appName := print $fullname "-" .name }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ print $appName "-" .image.tag | replace "." "-" }}
  labels:
    app: {{ $appName }}
spec:
  replicas: {{ .replicaCount }}
  selector:
    matchLabels:
      app: {{ $appName }}
      ver: "{{ .image.tag }}"
  template:
    metadata:
      labels:
        app: {{ $appName }}
        ver: "{{ .image.tag }}"
    spec:
      containers:
        - name: {{ $appName }}
          imagePullPolicy: "Always"
          image: "{{ .image.repository }}:{{ .image.tag | default .Globals.Chart.AppVersion }}"
          ports:
            - containerPort: {{ .port }}
          env: 
          {{- with .env }}
          {{- toYaml . | nindent 10 }}
          {{- end }}
{{- end }}
