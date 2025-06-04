# Variables principales
$repoURL = "https://github.com/rcorderoayigroup/Multi-Tenancy-Project.git"
$root = "Multi-Tenancy-Project"
$appName = "app1"
$projectName = "team-a"
$envs = @("dev", "test", "prod")

# Crear estructura de carpetas
New-Item -ItemType Directory -Path "$root\projects" -Force
New-Item -ItemType Directory -Path "$root\apps\$projectName\$appName\base" -Force

foreach ($env in $envs) {
    New-Item -ItemType Directory -Path "$root\apps\$projectName\$appName\overlays\$env" -Force
}

# Crear AppProject YAML
@"
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: $projectName
  namespace: argocd
spec:
  description: Project for Team A apps
  sourceRepos:
    - '*'
  destinations:
    - namespace: $projectName-*
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: '*'
      kind: '*'
"@ | Set-Content "$root\projects\$projectName-project.yaml"

# Crear deployment base y kustomization
@"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $appName
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $appName
  template:
    metadata:
      labels:
        app: $appName
    spec:
      containers:
        - name: $appName
          image: nginx
          ports:
            - containerPort: 80
"@ | Set-Content "$root\apps\$projectName\$appName\base\deployment.yaml"

@"
resources:
  - deployment.yaml
"@ | Set-Content "$root\apps\$projectName\$appName\base\kustomization.yaml"

# Crear overlays para dev/test/prod y los manifests de Application
foreach ($env in $envs) {
    $ns = "$projectName-$env"

    # Namespace manifest
    @"
apiVersion: v1
kind: Namespace
metadata:
  name: $ns
"@ | Set-Content "$root\apps\$projectName\$appName\overlays\$env\namespace.yaml"

    # Overlay kustomization
    @"
resources:
  - ../../base
  - namespace.yaml
namespace: $ns
"@ | Set-Content "$root\apps\$projectName\$appName\overlays\$env\kustomization.yaml"

    # Application YAML
    @"
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: $projectName-$appName-$env
  namespace: argocd
spec:
  project: $projectName
  source:
    repoURL: $repoURL
    targetRevision: HEAD
    path: apps/$projectName/$appName/overlays/$env
  destination:
    server: https://kubernetes.default.svc
    namespace: $ns
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
"@ | Set-Content "$root\apps\$projectName\$appName\overlays\$env\application.yaml"
}

Write-Host "✅ Todo listo. Repositorio '$root' generado con estructura Multi-Tenancy para Argo CD."
