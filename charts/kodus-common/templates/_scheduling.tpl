{{/*
Pod scheduling — nodeSelector / affinity / tolerations.

One door for every pod spec in the chart so the resolution rule lives in one
place: a per-workload override REPLACES the global default for that field (it
does not merge), and an unset/empty override falls back to the global default.
`default` treats an empty map ({}) or list ([]) as unset, so a service that
leaves a field at its empty default inherits the global one.

Call with (dict "root" $ "override" $svc) to resolve a per-service/datastore
override, or (dict "root" $) for a pod that only takes the global defaults
(e.g. the migration Job). The output is the three pod-spec fields, each emitted
only when non-empty — so an all-default install renders nothing and behaves
exactly as before.
*/}}
{{- define "kodus-common.scheduling" -}}
{{- $root := .root -}}
{{- $override := .override | default dict -}}
{{- $nodeSelector := $override.nodeSelector | default $root.Values.nodeSelector -}}
{{- $affinity := $override.affinity | default $root.Values.affinity -}}
{{- $tolerations := $override.tolerations | default $root.Values.tolerations -}}
{{- with $nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}
