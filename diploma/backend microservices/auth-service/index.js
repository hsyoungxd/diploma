require('dotenv').config({ path: '../.env' });
const express = require('express');
const cors = require('cors');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { MongoClient } = require('mongodb');

const app = express();
app.use(cors());
app.use(express.json());
app.use((req, res, next) => {
  console.log(`[AUTH-SERVICE] ${req.method} ${req.url}`);
  next();
});
let db;
(async () => {
    try {
        const client = new MongoClient(process.env.MONGO_URI);
        await client.connect();
        db = client.db();
        console.log('Auth-service connected');
        app.listen(4001, () => console.log('Auth-service на порту 4001'));
    } catch (err) {
        console.error('Ошибка подключения к MongoDB:', err);
        process.exit(1);
    }
})();

app.post('/register', async (req, res) => {
    try {
        const { displayname, username, email, phone, password } = req.body;
        const avatar = '';
        if (!displayname || !username || !email || !phone || !password)
            return res.status(400).json({ message: 'Заполните все поля' });

        const userWithSameEmail = await db.collection('users').findOne({ email });
        if (userWithSameEmail) return res.status(400).json({ message: 'Email уже занят' });

        const userWithSameUsername = await db.collection('users').findOne({ username });
        if (userWithSameUsername) return res.status(400).json({ message: 'Ник уже занят' });

        const hashedPassword = await bcrypt.hash(password, 10);

        const result = await db.collection('users').insertOne({
            username,
            displayname,
            avatar,
            email,
            phone,
            password: hashedPassword,
            createdAt: new Date(),
            balance: 0.00,
            cards: [],
            friends: [],
            transactions: [],
            requests: { sent: [], received: [] },
        });

        const newUser = await db.collection('users').findOne({ _id: result.insertedId });

        const token = jwt.sign(
            {
                userId: newUser._id,
                email: newUser.email,
                username: newUser.username,
            },
            process.env.JWT_SECRET,
            { expiresIn: '1d' }
        );

        const { password: _removed, ...safeUser } = newUser;

        return res.status(201).json({
            message: 'Пользователь успешно зарегистрирован',
            token,
            user: safeUser,
            id: newUser._id,
        });
    } catch (error) {
        console.error('Ошибка регистрации:', error);
        return res.status(500).json({ message: 'Внутренняя ошибка сервера' });
    }
});

app.post('/login', async (req, res) => {
    try {
        const { username, password } = req.body;
        if (!username || !password) {
            return res.status(400).json({ message: 'Укажите username и пароль' });
        }

        const user = await db.collection('users').findOne({ username });
        if (!user) return res.status(400).json({ message: 'Неверные учетные данные' });

        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) return res.status(400).json({ message: 'Неверные учетные данные' });

        const token = jwt.sign(
            {
                userId: user._id,
                email: user.email,
                username: user.username,
            },
            process.env.JWT_SECRET,
            { expiresIn: '1d' }
        );

        const { password: _removed, ...safeUser } = user;

        return res.json({
            message: 'Логин успешен',
            token,
            user: { ...safeUser, id: user._id },
        });
    } catch (error) {
        console.error('Ошибка логина:', error);
        return res.status(500).json({ message: 'Внутренняя ошибка сервера' });
    }
});

