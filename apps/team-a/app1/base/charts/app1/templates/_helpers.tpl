{{- define \"app1.name\" -}}
app1
{{- end }}

{{- define \"app1.fullname\" -}}
{{ include \"app1.name\" . }}
{{- end }}
