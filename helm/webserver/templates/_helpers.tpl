{{- define "webserver.name" -}}webserver{{- end }}
{{- define "webserver.fullname" -}}{{ .Release.Name }}-webserver{{- end }}
{{- define "webserver.labels" -}}
app.kubernetes.io/name: {{ include "webserver.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}
