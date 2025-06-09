# Crear estructura de carpetas
$paths = @(
  "apps/team-a/app1/base",
  "apps/team-a/app1/charts/app1/templates",
  "apps/team-a/app1/overlays/dev",
  "apps/team-a/app1/overlays/prod"
)
foreach ($path in $paths) {
  New-Item -ItemType Directory -Path $path -Force
}

# Crear Chart.yaml
@"
apiVersion: v2
name: app1
version: 0.1.0
description: A Helm chart for Kubernetes
"@ | Set-Content -Path "apps/team-a/app1/charts/app1/Chart.yaml"

# Crear values.yaml (base)
@"
replicaCount: 1

image:
  repository: nginx
  tag: latest
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 80

resources:
  limits:
    cpu: 100m
    memory: 128Mi
  requests:
    cpu: 100m
    memory: 128Mi
"@ | Set-Content -Path "apps/team-a/app1/values.yaml"

# Crear templates/deployment.yaml y service.yaml
@"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Release.Name }}
  template:
    metadata:
      labels:
        app: {{ .Release.Name }}
    spec:
      containers:
        - name: {{ .Release.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: {{ .Values.service.port }}
"@ | Set-Content -Path "apps/team-a/app1/charts/app1/templates/deployment.yaml"

@"
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}
spec:
  type: {{ .Values.service.type }}
  selector:
    app: {{ .Release.Name }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: {{ .Values.service.port }}
"@ | Set-Content -Path "apps/team-a/app1/charts/app1/templates/service.yaml"

# Crear kustomization.yaml en base
@"
helmCharts:
  - name: app1
    repo: file://charts
    releaseName: app1
    version: 0.1.0
    valuesFile: ../../values.yaml
"@ | Set-Content -Path "apps/team-a/app1/base/kustomization.yaml"

# Crear values-dev.yaml y values-prod.yaml
@"
replicaCount: 1
"@ | Set-Content -Path "apps/team-a/app1/overlays/dev/values-dev.yaml"

@"
replicaCount: 2
"@ | Set-Content -Path "apps/team-a/app1/overlays/prod/values-prod.yaml"

# Crear kustomization.yaml en overlays/dev
@"
resources:
  - ../../base

configMapGenerator:
  - name: my-config
    files:
      - values-dev.yaml

helmGlobals:
  chartHome: ../../base

helmCharts:
  - name: app1
    repo: file://../../base/charts
    version: 0.1.0
    releaseName: app1
    valuesFile: values-dev.yaml
"@ | Set-Content -Path "apps/team-a/app1/overlays/dev/kustomization.yaml"

# Crear kustomization.yaml en overlays/prod
@"
resources:
  - ../../base

configMapGenerator:
  - name: my-config
    files:
      - values-prod.yaml

helmGlobals:
  chartHome: ../../base

helmCharts:
  - name: app1
    repo: file://../../base/charts
    version: 0.1.0
    releaseName: app1
    valuesFile: values-prod.yaml
"@ | Set-Content -Path "apps/team-a/app1/overlays/prod/kustomization.yaml"

# Empaquetar el chart
helm package apps/team-a/app1/charts/app1 -d apps/team-a/app1/base
