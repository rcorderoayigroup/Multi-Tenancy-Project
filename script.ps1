# === SETUP ===
$basePath = "Multi-Tenancy-Project"
$appPath = "$basePath\apps\team-a\app1"
$chartPath = "$appPath\base\charts\app1"
$overlays = @("dev", "test", "prod")

# === DIRECTORIOS ===
$folders = @(
    "$chartPath\templates",
    "$basePath\argo\apps"
) + ($overlays | ForEach-Object { "$appPath\overlays\$_" })

foreach ($folder in $folders) {
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
}

# === HELM CHART ===
@"
apiVersion: v2
name: app1
description: Helm chart for app1
type: application
version: 0.1.0
appVersion: "1.0.0"
"@ | Set-Content "$chartPath\Chart.yaml"

@"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Chart.Name }}
spec:
  replicas: {{ .Values.replicaCount }}
  selector:
    matchLabels:
      app: {{ .Chart.Name }}
  template:
    metadata:
      labels:
        app: {{ .Chart.Name }}
    spec:
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: 80
"@ | Set-Content "$chartPath\templates\deployment.yaml"

@"
apiVersion: v1
kind: Service
metadata:
  name: {{ .Chart.Name }}
spec:
  type: {{ .Values.service.type }}
  selector:
    app: {{ .Chart.Name }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: 80
"@ | Set-Content "$chartPath\templates\service.yaml"

# === values.yaml base ===
@"
replicaCount: 1
image:
  repository: nginx
  tag: latest
  pullPolicy: IfNotPresent
service:
  type: ClusterIP
  port: 80
"@ | Set-Content "$appPath\base\values.yaml"

# === kustomization.yaml base ===
@"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

helmCharts:
  - name: app1
    releaseName: app1
    version: 0.1.0
    repo: file://charts/app1
    valuesFile: values.yaml
"@ | Set-Content "$appPath\base\kustomization.yaml"

# === OVERLAYS ===
$replicas = @{ "dev" = 2; "test" = 3; "prod" = 4 }

foreach ($env in $overlays) {
    @"
replicaCount: $($replicas[$env])
"@ | Set-Content "$appPath\overlays\$env\values.yaml"

    @"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

helmCharts:
  - name: app1
    releaseName: app1
    version: 0.1.0
    repo: file://../base/charts/app1
    valuesFile: values.yaml
"@ | Set-Content "$appPath\overlays\$env\kustomization.yaml"
}

# === Argo CD PROJECT ===
@"
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-a
  namespace: argocd
spec:
  description: Project for team-a
  sourceRepos:
    - '*'
  destinations:
    - namespace: '*'
      server: '*'
  clusterResourceWhitelist:
    - group: '*'
      kind: '*'
  namespaceResourceWhitelist:
    - group: '*'
      kind: '*'
"@ | Set-Content "$basePath\argo\project-team-a.yaml"

# === Argo CD APPLICATIONS ===
foreach ($env in $overlays) {
    @"
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: app1-$env
  namespace: argocd
spec:
  project: team-a
  source:
    repoURL: https://github.com/YOUR_USER/YOUR_REPO.git
    targetRevision: HEAD
    path: apps/team-a/app1/overlays/$env
    plugin:
      name: ""
  destination:
    server: https://kubernetes.default.svc
    namespace: team-a-$env
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
"@ | Set-Content "$basePath\argo\apps\app1-$env.yaml"
}

Write-Host "`n✅ Multi-tenancy completo generado en '$basePath'"
Write-Host "👉 Reemplazá 'YOUR_USER/YOUR_REPO.git' en los YAML de Argo CD."
