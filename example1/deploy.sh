#!/bin/bash

# Step 1: Set up environment variables (you can adjust these as needed)
NODEJS_APP_DIR="."  # Path to the root directory where server.js and package.json are located
NGINX_CONFIG_DIR="./nginx"  # Path to your NGINX config folder
DOCKER_IMAGE_REPO="docker.io/paphat82"  # Docker Hub username or private repository name
POSTGRES_IMAGE="postgres:13"  # Official PostgreSQL image (we will use this directly)
NAMESPACE="my-project"  # Kubernetes namespace (adjust this as needed)

# Step 2: Build Docker images for Node.js and NGINX
echo "Building Docker images..."

# Build Node.js image
docker build -t ${DOCKER_IMAGE_REPO}/nodejs-app:latest ${NODEJS_APP_DIR}
if [ $? -ne 0 ]; then
    echo "Error building Node.js image."
    exit 1
fi

# Build NGINX image
docker build -t ${DOCKER_IMAGE_REPO}/nginx-reverse-proxy:latest ${NGINX_CONFIG_DIR}
if [ $? -ne 0 ]; then
    echo "Error building NGINX image."
    exit 1
fi

# Step 3: Push Docker images to Docker Hub (Optional: only if you want to push them to a registry)
echo "Pushing Docker images to Docker Hub..."
docker push ${DOCKER_IMAGE_REPO}/nodejs-app:latest
docker push ${DOCKER_IMAGE_REPO}/nginx-reverse-proxy:latest
if [ $? -ne 0 ]; then
    echo "Error pushing Docker images to Docker Hub."
    exit 1
fi

# Step 4: Create Kubernetes YAML files for PostgreSQL, Node.js, and NGINX

echo "Creating Kubernetes YAML files..."

# PostgreSQL Persistent Volume and Claim
cat <<EOF > postgres-pv-pvc.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: postgres-pv
  namespace: ${NAMESPACE}
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: /data/postgres  # Change to your environment
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: ${NAMESPACE}
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF

# PostgreSQL Deployment and Service
cat <<EOF > postgres-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
        - name: postgres
          image: ${POSTGRES_IMAGE}  # Use official PostgreSQL image
          env:
            - name: POSTGRES_USER
              value: "postgres"
            - name: POSTGRES_PASSWORD
              value: "123"
            - name: POSTGRES_DB
              value: "testdb"
          ports:
            - containerPort: 5432
          volumeMounts:
            - name: postgres-storage
              mountPath: /var/lib/postgresql/data
      volumes:
        - name: postgres-storage
          persistentVolumeClaim:
            claimName: postgres-pvc
EOF

cat <<EOF > postgres-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: ${NAMESPACE}
spec:
  selector:
    app: postgres
  ports:
    - protocol: TCP
      port: 5432
      targetPort: 5432
  clusterIP: None
EOF

# Node.js Deployment and Service
cat <<EOF > nodejs-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nodejs-app
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nodejs
  template:
    metadata:
      labels:
        app: nodejs
    spec:
      containers:
        - name: nodejs
          image: ${DOCKER_IMAGE_REPO}/nodejs-app:latest  # Use the custom Node.js image
          ports:
            - containerPort: 8080
          env:
            - name: DB_HOST
              value: "postgres"
            - name: DB_USER
              value: "postgres"
            - name: DB_PASSWORD
              value: "123"
            - name: DB_NAME
              value: "testdb"
EOF

cat <<EOF > nodejs-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: nodejs-app
  namespace: ${NAMESPACE}
spec:
  selector:
    app: nodejs
  ports:
    - protocol: TCP
      port: 8080
      targetPort: 8080
  clusterIP: None
EOF

# NGINX Deployment and Service
cat <<EOF > nginx-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-proxy
  namespace: ${NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: ${DOCKER_IMAGE_REPO}/nginx-reverse-proxy:latest  # Use the custom NGINX image
          ports:
            - containerPort: 80
EOF

cat <<EOF > nginx-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: ${NAMESPACE}
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: LoadBalancer
EOF

# Step 5: Deploy resources to Kubernetes

echo "Deploying resources to Kubernetes..."

kubectl apply -f postgres-pv-pvc.yaml -n ${NAMESPACE}
kubectl apply -f postgres-deployment.yaml -n ${NAMESPACE}
kubectl apply -f postgres-service.yaml -n ${NAMESPACE}
kubectl apply -f nodejs-deployment.yaml -n ${NAMESPACE}
kubectl apply -f nodejs-service.yaml -n ${NAMESPACE}
kubectl apply -f nginx-deployment.yaml -n ${NAMESPACE}
kubectl apply -f nginx-service.yaml -n ${NAMESPACE}

# Step 6: Check Kubernetes resources

echo "Checking status of Kubernetes resources..."
kubectl get pods -n ${NAMESPACE}
kubectl get services -n ${NAMESPACE}
kubectl get deployments -n ${NAMESPACE}

echo "Deployment complete!"
