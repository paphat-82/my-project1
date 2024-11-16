# ใช้ Node.js image ที่เหมาะสม
FROM node:14

# ตั้ง working directory
WORKDIR /usr/src/app

# คัดลอกไฟล์ package.json และ package-lock.json
COPY package*.json ./

# ติดตั้ง dependencies
RUN npm install

# คัดลอกไฟล์ทั้งหมดจากโปรเจกต์ไปยัง working directory
COPY . .

# เปิด port ที่ Node.js จะรัน
EXPOSE 8080

# สั่งให้ container รันแอปพลิเคชัน
CMD ["node", "server.js"]
