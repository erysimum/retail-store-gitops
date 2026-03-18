{{/*
Common labels applied to every resource.
Called with: {{ include "microservice.labels" . }}
*/}}
{{- define "microservice.labels" -}}
app: {{ .Values.name }}
app.kubernetes.io/name: {{ .Values.name }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Values.image.tag | default .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: retail-store
{{- end }}

{{/*
Selector labels — used in  podSelectorand service selector.
Must be a SUBSET of the common labels.
These must NEVER change after first deploy, or K8s loses track of pods.
Called with: {{ include "microservice.selectorLabels" . }}
*/}}
{{- define "microservice.selectorLabels" -}}
app: {{ .Values.name }}
app.kubernetes.io/name: {{ .Values.name }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}
