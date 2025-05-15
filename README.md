# 💸 TengriPay

Проект состоит из двух частей:  
- **Backend** на Node.js (монолит, Express + MongoDB)  
- **Frontend** на Flutter (тестировался на iPhone 16 Plus, iOS 18.1)  

---

## 🧠 Требования

- **Flutter SDK**: 3.22.1  
- **Dart**: 3.4.1  
- **Node.js**: v20.12.2  
- **MongoDB Atlas**: подключение через `MONGO_URI`  
- **iPhone 16 Plus** с iOS 18.1 (другие устройства не тестировались)

---

## ⚙️ Установка и запуск Backend (Node.js)

1. Перейдите в папку `backend monolith`:
   ```bash
   cd backend/monolith
   ```

2. Установите зависимости:
   ```bash
   npm install
   ```

3. Создайте `.env` файл:
   ```env
   MONGO_URI=mongodb+srv://<USERNAME>:<PASSWORD>@<CLUSTER>.mongodb.net/<DB_NAME>?retryWrites=true&w=majority&appName=<APP_NAME>
   JWT_SECRET=your_secret_key
   PORT=4000
   ```

4. Запустите сервер:
   ```bash
   npm run dev
   ```

5. Сервер будет доступен по адресу:  
   `http://localhost:4000`

---

## 📱 Установка и запуск Frontend (Flutter)

1. Перейдите в папку:
   ```bash
   cd frontend
   ```

2. Установите зависимости:
   ```bash
   flutter pub get
   ```

3. Запустите на симуляторе iOS или iPhone:
   ```bash
   flutter run
   ```

---

## ⚠️ Важно

- На реальном iPhone обязательно используй внешний IP или ngrok — `localhost` не сработает.  
- На эмуляторе Mac `localhost` можно оставить.

---

## 🌐 Информация о тестировании

- 📱 Устройство: iPhone 16 Plus  
- 💽 iOS: 18.1  
- Другие устройства не тестировались.

---

## ✅ Стек

- Backend: Node.js, Express, MongoDB  
- Frontend: Flutter  
- Auth: JWT  
- DB: MongoDB Atlas

---

## 🛠 Команды

```bash
flutter devices
flutter build ios --release
node --version
```
