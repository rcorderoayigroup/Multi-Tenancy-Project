# Script para recrear estructura apps/team-a/app1 con Helm chart y Kustomize
# Requiere helm y kubectl instalados en PATH

$root = "apps\team-a\app1"

# Borra carpeta si existe
if (Test-Path $root) {
    Write-Host "Borrando carpeta $root"
    Remove-Item -Recurse -Force $root
}

# Crear carpetas base y overlay/prod
Write-Host "Creando carpetas base y overlay/prod..."
New-Item -ItemType Directory -Path "$root\base" -Force | Out-Null
New-Item -ItemType Directory -Path "$root\base\charts" -Force | Out-Null
New-Item -ItemType Directory -Path "$root\overlay\prod" -Force | Out-Null

# Crear Helm chart básico con helm create
Write-Host "Creando Helm chart básico en base/charts/app1 ..."
helm create "$root\base\charts\app1"

# Borra templates de ejemplo innecesarios para dejar solo deployment y service
Write-Host "Limpiando templates innecesarios del chart..."
Remove-Item "$root\base\charts\app1\templates\hpa.yaml" -ErrorAction SilentlyContinue
Remove-Item "$root\base\charts\app1\templates\ingress.yaml" -ErrorAction SilentlyContinue
Remove-Item "$root\base\charts\app1\templates\tests" -Recurse -Force -ErrorAction SilentlyContinue

# Crear values.yaml base simple (puedes editar después)
$valuesYaml = @"
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
"@

$valuesPath = "$root\base\values.yaml"
Write-Host "Creando values.yaml base..."
$valuesYaml | Out-File -Encoding utf8 $valuesPath

# Crear kustomization.yaml en base/ usando chartPath y values.yaml
$kustomBase = @"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

helmCharts:
  - name: app1
    chartPath: charts/app1
    releaseName: app1
    valuesFile: values.yaml
"@

$kustomBasePath = "$root\base\kustomization.yaml"
Write-Host "Creando kustomization.yaml en base/ ..."
$kustomBase | Out-File -Encoding utf8 $kustomBasePath

# Crear kustomization.yaml en overlay/prod que usa base/
$kustomOverlayProd = @"
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
  - ../../base

namespace: team-a-prod

commonLabels:
  app.kubernetes.io/part-of: app1

patchesStrategicMerge:
  - patch.yaml
"@

$kustomOverlayProdPath = "$root\overlay\prod\kustomization.yaml"
Write-Host "Creando kustomization.yaml en overlay/prod/ ..."
$kustomOverlayProd | Out-File -Encoding utf8 $kustomOverlayProdPath

# Crear patch.yaml en overlay/prod para cambiar replicas a 2 por ejemplo
$patchYaml = @"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app1
spec:
  replicas: 2
"@

$patchPath = "$root\overlay\prod\patch.yaml"
Write-Host "Creando patch.yaml en overlay/prod/ para modificar replicas..."
$patchYaml | Out-File -Encoding utf8 $patchPath

Write-Host "Estructura apps/team-a/app1 creada correctamente."
Write-Host "Recomendación: luego editá values.yaml y patch.yaml según necesites."
