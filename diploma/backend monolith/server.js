require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { MongoClient, ObjectId } = require('mongodb');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const verifyToken = require('./verifyToken');

const app = express();
app.use(cors());
app.use(express.json());


let db;
async function connectToDB() {
    const client = new MongoClient(process.env.MONGO_URI);
    await client.connect();
    db = client.db('diploma');
    console.log('MongoDB connected');
     const collections = await db.listCollections().toArray();
    console.log('📦 Collections:');
    collections.forEach(col => console.log(`- ${col.name}`));
}



// REGISTER
app.post('/api/auth/register', async (req, res) => {
    try {
        const { displayname, username, email, phone, password} = req.body;
        const avatar = '';
        if ( !displayname || !username || !email || !phone || !password) {
            return res.status(400).json({ message: 'Заполните все поля: username, email, phone, password' });
        }

        const userWithSameEmail = await db.collection('users').findOne({ email });
        if (userWithSameEmail) {
            return res.status(400).json({ message: 'Email уже занят' });
        }

        const userWithSameUsername = await db.collection('users').findOne({ username });
        if (userWithSameUsername) {
            return res.status(400).json({ message: 'Ник уже занят' });
        }

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
            requests: {sent: [], received: []},
            transactionRequests: {sent: [], received: []}
        });

        const newUser = await db.collection('users').findOne({ _id: result.insertedId });

        console.log("New user data: ", newUser);


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

        // Detailed error logging
        if (error instanceof SyntaxError) {
            console.error('Syntax error encountered during registration');
        } else if (error instanceof TypeError) {
            console.error('Type error encountered during registration');
        }

        return res.status(500).json({ message: 'Внутренняя ошибка сервера' });
    }
});

// LOGIN
app.post('/api/auth/login', async (req, res) => {
    try {
        const { username, password } = req.body;

        if (!username || !password) {
            return res.status(400).json({ message: 'Укажите username и пароль' });
        }

        const user = await db.collection('users').findOne({ username });
        if (!user) {
            return res.status(400).json({ message: 'Неверные учетные данные' });
        }

        const isMatch = await bcrypt.compare(password, user.password);
        if (!isMatch) {
            return res.status(400).json({ message: 'Неверные учетные данные' });
        }

        const token = jwt.sign(
            { userId: user._id, email: user.email, username: user.username },
            process.env.JWT_SECRET,
            { expiresIn: '1d' }
        );
        const { password: _removed, ...safeUser } = user;

        return res.json({
            message: 'Логин успешен',
            token,
            user: {
                ...safeUser, id: user._id
            },
        });
    } catch (error) {
        console.error('Ошибка логина:', error);
        return res.status(500).json({ message: 'Внутренняя ошибка сервера' });
    }
});

app.get('/api/users/:id', verifyToken, async (req, res) => {
    try {
        const userId = req.params.id;
    
        // Проверка, что userId из токена совпадает с userId в параметре
        if (req.user.userId !== userId) {
            return res.status(403).json({ message: 'Forbidden' });
        }
  
        const user = await db.collection('users').findOne({ _id: new ObjectId(userId) });
  
        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }
        const { password, ...userData } = user;
  
        return res.json(userData);
    } catch (error) {
        console.error('Ошибка получения данных пользователя:', error);
        return res.status(500).json({ message: 'Внутренняя ошибка сервера' });
    }
});

// POST /api/transactions — обработка транзакций (deposit)
app.post('/api/transactions/deposit', verifyToken, async (req, res) => {
    try {
        const { userId, amount, isSaved, cardNumber, expirationMonth, expirationYear, cvv, cardHolder } = req.body;
    
        // Проверка, что сумма больше 0
        if (amount <= 0) {
            return res.status(400).json({ message: 'Amount must be greater than 0' });
        }
        if(expirationMonth <= 0 || expirationMonth > 12){
            return res.status(400).json({ message: 'Please enter a valid month' });
        }
        if(expirationYear == 25 && expirationMonth <= 5){
            return res.status(400).json({ message: 'Please enter a valid expiration date' });
        }
        if(expirationYear < 25){
            return res.status(400).json({ message: 'Please enter a valid year' });
        }
    
        // Поиск пользователя по userId
        const user = await db.collection('users').findOne({ _id: new ObjectId(userId) });
    
        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }
    
        let updatedBalance = user.balance;
    
        // Если флаг isSaved равен true, проверяем, если карта еще не сохранена
        if (isSaved) {
            // Проверка на существование карты
            const existingCard = user.cards.find(card => card.cardNumber === cardNumber);
            if (!existingCard) {
            // Если карты нет, сохраняем карту
            await db.collection('users').updateOne(
                { _id: new ObjectId(userId) },
                {
                $push: {
                    cards: {
                    cardNumber,
                    expirationMonth,
                    expirationYear,
                    cvv,
                    cardHolder,
                    createdAt: new Date(),
                    },
                },
                }
            );
            console.log('Card saved');
            }
        }
    
        // Увеличиваем баланс на сумму депозита
        updatedBalance += amount;
    
        // Обновляем баланс пользователя в базе данных
        await db.collection('users').updateOne(
            { _id: new ObjectId(userId) },
            { $set: { balance: updatedBalance } }
        );
        
        const transaction = {
            type: 'deposit',
            to: userId, // Тип транзакции
            from: cardNumber, // Номер карты, на которую был сделан депозит
            amount: amount, // Сумма
            date: new Date(), // Дата транзакции
            message: '',
            isPublic: false,
            role: "receiver",
        };

        await db.collection('users').updateOne(
            { _id: new ObjectId(userId) },
            {
                $push: {
                    transactions: transaction, // Добавляем транзакцию в массив transactions
                },
            }
        );
        
        return res.status(200).json({
            message: 'Deposit successful',
            newBalance: updatedBalance,
        });
    } catch (error) {
        console.error('Error processing deposit:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
});
  

app.post('/api/transactions/withdraw', verifyToken, async (req, res) => {
    try {
        const { userId, amount, cardNumber, cardHolder } = req.body;
    
        // Проверка, что сумма больше 0
        if (amount <= 0) {
            return res.status(400).json({ message: 'Amount must be greater than 0' });
        }
    
        // Поиск пользователя по userId
        const user = await db.collection('users').findOne({ _id: new ObjectId(userId) });
    
        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }
    
        let updatedBalance = user.balance;
    
        if (updatedBalance < amount) {
            return res.status(400).json({ message: 'Insufficient balance' });
        }

        // Увеличиваем баланс на сумму депозита
        updatedBalance -= amount;
    
        // Обновляем баланс пользователя в базе данных
        await db.collection('users').updateOne(
            { _id: new ObjectId(userId) },
            { $set: { balance: updatedBalance } }
        );
        
        const transaction = {
            type: 'withdrawal', 
            to: cardNumber,
            from: userId,
            amount: amount,
            date: new Date(), 
            message: '',
            isPublic: false,
            role: "sender",
        };

        await db.collection('users').updateOne(
            { _id: new ObjectId(userId) },
            {
                $push: {
                    transactions: transaction,
                },
            }
        );
        
        return res.status(200).json({
            message: 'Withdrawal successful',
            newBalance: updatedBalance,
        });
    } catch (error) {
        console.error('Error processing deposit:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
});
  


// Remove Card from User Profile (Backend Route)
app.post('/api/users/remove-card', verifyToken, async (req, res) => {
    try {
        const { cardNumber } = req.body;
        const userId = req.user.userId; // userId from token

        // Find the user by ID
        const user = await db.collection('users').findOne({ _id: new ObjectId(userId) });

        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }

        // Check if the user has the card in their saved cards
        const cardIndex = user.cards.findIndex(card => card.cardNumber === cardNumber);

        if (cardIndex === -1) {
            return res.status(400).json({ message: 'Card not found in saved cards' });
        }

        // Remove the card from the user's saved cards array
        user.cards.splice(cardIndex, 1);

        // Update the user's saved cards in the database
        await db.collection('users').updateOne(
            { _id: new ObjectId(userId) },
            { $set: { cards: user.cards } }
        );

        return res.status(200).json({ message: 'Card removed successfully' });
    } catch (error) {
        console.error('Error removing card:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
});


app.post('/api/users/add-friend', verifyToken, async (req, res) => {
    try {
        const { friendUsername } = req.body;
        const userId = req.user.userId;
        
        if (!friendUsername) {
            return res.status(400).json({ message: 'Username of the friend is required' });
        }

        // Find the user who is sending the request
        const user = await db.collection('users').findOne({ _id: new ObjectId(userId) });
        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }
        // Find the friend by username
        const friend = await db.collection('users').findOne({ username: friendUsername });
        if (!friend) {
            return res.status(404).json({ message: 'User not found' });
        }

        if (!user.requests) {
            user.requests = { sent: [], received: [] };
        }  

        if(user.username == friendUsername){
            return res.status(400).json({ message: 'You can\'t send a friend request to yourself' });
        }

        const isRequestSent = user.requests.sent.find(username => username === friendUsername);
        if (isRequestSent) {
            return res.status(400).json({ message: 'Friend request already sent' });
        }
        const isRequestReceived = user.requests.received.find(username => username === friendUsername);
        if (isRequestReceived) {
            return res.status(401).json({ message: 'Friend request already received' });
        }

        user.requests.sent.push(friendUsername);

        if (!friend.requests) {
            friend.requests = { sent: [], received: [] };
        }
        friend.requests.received.push(user.username);

        // Add the friend to the "sent" list for the user
        await db.collection('users').updateOne(
            { _id: new ObjectId(userId) },
            { $push: { 'requests.sent': friendUsername } }
        );

        // Optionally, you could add the user's username to the "received" list for the friend
        await db.collection('users').updateOne(
            { _id: new ObjectId(friend._id) },
            { $push: { 'requests.received': user.username } }
        );

        return res.status(200).json({ message: 'Friend request sent successfully' });
    } catch (error) {
        console.error('Error sending friend request:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
});

app.post('/api/users/friends-info', verifyToken, async (req, res) => {
    try {
        const { friendsUsernames, receivedUsernames, sentUsernames } = req.body;
        
        console.log('Friends:', friendsUsernames);
        console.log('Received Requests:', receivedUsernames);
        console.log('Sent Requests:', sentUsernames);

        if (!Array.isArray(friendsUsernames) || !Array.isArray(receivedUsernames) || !Array.isArray(sentUsernames)) {
            return res.status(400).json({ message: 'Invalid input data' });
        }

        // Получаем подробную информацию о друзьях
        const friendsDetails = await db.collection('users').find({
            username: { $in: friendsUsernames }
        }).toArray();

        // Получаем подробную информацию о полученных запросах
        const receivedRequestsDetails = await db.collection('users').find({
            username: { $in: receivedUsernames }
        }).toArray();

        // Получаем подробную информацию об отправленных запросах
        const sentRequestsDetails = await db.collection('users').find({
            username: { $in: sentUsernames }
        }).toArray();

        return res.json({
            friends: friendsDetails.map(friend => ({
                username: friend.username,
                displayname: friend.displayname,
                avatar: friend.avatar,
            })),
            receivedRequests: receivedRequestsDetails.map(request => ({
                username: request.username,
                displayname: request.displayname,
                avatar: request.avatar,
            })),
            sentRequests: sentRequestsDetails.map(request => ({
                username: request.username,
                displayname: request.displayname,
                avatar: request.avatar,
            })),
        });
        
    } catch (error) {
        console.error('Ошибка получения информации о друзьях и запросах:', error);
        return res.status(500).json({ message: 'Внутренняя ошибка сервера' });
    }
});

app.post('/api/users/cancel-friend-request', verifyToken, async (req, res) => {
  try {
    const { userId, friendUsername } = req.body;
    const user = await db.collection('users').findOne({ _id: new ObjectId(userId) });
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Удаляем из списка отправленных запросов
    user.requests.sent = user.requests.sent.filter(username => username !== friendUsername);
    
    // Удаляем из списка полученных запросов
    const friend = await db.collection('users').findOne({ username: friendUsername });
    if (!friend) {
      return res.status(404).json({ message: 'Friend not found' });
    }

    friend.requests.received = friend.requests.received.filter(username => username !== user.username);

    // Обновляем данные пользователя и друга
    await db.collection('users').updateOne(
      { _id: new ObjectId(userId) },
      { $set: { 'requests.sent': user.requests.sent } }
    );
    await db.collection('users').updateOne(
      { username: friendUsername },
      { $set: { 'requests.received': friend.requests.received } }
    );

    return res.status(200).json({ message: 'Friend request canceled successfully' });
  } catch (error) {
    console.error('Error canceling friend request:', error);
    return res.status(500).json({ message: 'Internal server error' });
  }
});


app.post('/api/users/accept-friend-request', verifyToken, async (req, res) => {
  try {
    const { userId, friendUsername } = req.body;
    
    const user = await db.collection('users').findOne({ _id: new ObjectId(userId) });
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const friend = await db.collection('users').findOne({ username: friendUsername });
    if (!friend) {
      return res.status(404).json({ message: 'Friend not found' });
    }

    // Убираем из списка received и добавляем в friends
    user.requests.received = user.requests.received.filter(username => username !== friendUsername);
    user.friends.push(friendUsername);

    // Убираем из списка sent у друга и добавляем в его friends
    friend.requests.sent = friend.requests.sent.filter(username => username !== user.username);
    friend.friends.push(user.username);

    // Обновляем обоих пользователей
    await db.collection('users').updateOne(
      { _id: new ObjectId(userId) },
      { $set: { 'requests.received': user.requests.received, friends: user.friends } }
    );

    await db.collection('users').updateOne(
      { _id: new ObjectId(friend._id) },
      { $set: { 'requests.sent': friend.requests.sent, friends: friend.friends } }
    );

    return res.status(200).json({ message: 'Friend request accepted successfully' });
  } catch (error) {
    console.error('Error accepting friend request:', error);
    return res.status(500).json({ message: 'Internal server error' });
  }
});


app.post('/api/users/decline-friend-request', verifyToken, async (req, res) => {
  try {
    const { userId, friendUsername } = req.body;

    const user = await db.collection('users').findOne({ _id: new ObjectId(userId) });
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const friend = await db.collection('users').findOne({ username: friendUsername });
    if (!friend) {
      return res.status(404).json({ message: 'Friend not found' });
    }

    // Убираем заявку из списка received и sent
    user.requests.received = user.requests.received.filter(username => username !== friendUsername);
    friend.requests.sent = friend.requests.sent.filter(username => username !== user.username);

    // Обновляем обоих пользователей
    await db.collection('users').updateOne(
      { _id: new ObjectId(userId) },
      { $set: { 'requests.received': user.requests.received } }
    );

    await db.collection('users').updateOne(
      { _id: new ObjectId(friend._id) },
      { $set: { 'requests.sent': friend.requests.sent } }
    );

    return res.status(200).json({ message: 'Friend request declined successfully' });
  } catch (error) {
    console.error('Error declining friend request:', error);
    return res.status(500).json({ message: 'Internal server error' });
  }
});

app.post('/api/users/delete-friend', verifyToken, async (req, res) => {
  try {
    const { userId, friendUsername } = req.body;

    // Проверка, что userId из токена совпадает с userId в параметре
    if (req.user.userId !== userId) {
      return res.status(403).json({ message: 'Forbidden' });
    }

    // Найти пользователя по userId
    const user = await db.collection('users').findOne({ _id: new ObjectId(userId) });
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Найти друга по friendUsername
    const friend = await db.collection('users').findOne({ username: friendUsername });
    if (!friend) {
      return res.status(404).json({ message: 'Friend not found' });
    }

    // Удаляем друга из списка friends пользователя
    user.friends = user.friends.filter(friend => friend !== friendUsername);

    // Удаляем пользователя из списка friends друга
    friend.friends = friend.friends.filter(friend => friend !== user.username);

    // Обновляем списки друзей в базе данных
    await db.collection('users').updateOne(
      { _id: new ObjectId(userId) },
      { $set: { friends: user.friends } }
    );

    await db.collection('users').updateOne(
      { _id: new ObjectId(friend._id) },
      { $set: { friends: friend.friends } }
    );

    // Удаляем из списка запросов
    user.requests.sent = user.requests.sent.filter(username => username !== friendUsername);
    friend.requests.received = friend.requests.received.filter(username => username !== user.username);

    // Обновляем списки запросов в базе данных
    await db.collection('users').updateOne(
      { _id: new ObjectId(userId) },
      { $set: { 'requests.sent': user.requests.sent } }
    );

    await db.collection('users').updateOne(
      { _id: new ObjectId(friend._id) },
      { $set: { 'requests.received': friend.requests.received } }
    );

    return res.status(200).json({ message: 'Friend successfully removed' });
  } catch (error) {
    console.error('Error removing friend:', error);
    return res.status(500).json({ message: 'Internal server error' });
  }
});

app.post('/api/users/username-info', verifyToken, async (req, res) => {
  try {
    const { username } = req.body;
    const currentUsername = req.user.username;
    if (!username) {
      return res.status(400).json({ message: 'Username is required' });
    }

    const user = await db.collection('users').findOne({ username });

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    if (username == currentUsername) {
      return res.status(400).json({ message: 'You can\'t send money to yourself' });
    }

    const { password, ...safeUser } = user;
    return res.status(200).json({
      username: safeUser.username,
      displayname: safeUser.displayname,
      avatar: safeUser.avatar,
    });
  } catch (error) {
    console.error('Ошибка получения инфо по username:', error);
    return res.status(500).json({ message: 'Internal server error' });
  }
});

app.post('/api/transactions/request', verifyToken, async (req, res) => {
  try {
    const { recipient, amount, note, isPublic } = req.body;
    const senderId = req.user.userId;

    if (!recipient || !amount || isNaN(amount)) {
      return res.status(400).json({ message: 'Invalid input' });
    }

    // Нельзя запрашивать у самого себя
    const sender = await db.collection('users').findOne({ _id: new ObjectId(senderId) });
    if (!sender) return res.status(404).json({ message: 'Sender not found' });
    if (sender.username === recipient) {
      return res.status(400).json({ message: 'You can\'t request money from yourself' });
    }

    const receiver = await db.collection('users').findOne({ username: recipient });
    if (!receiver) return res.status(404).json({ message: 'Recipient not found' });

    const requestObjForSender = {
      to: recipient,
      amount: parseFloat(amount),
      note,
      isPublic: !!isPublic,
      date: new Date()
    };

    const requestObjForReceiver = {
      from: sender.username,
      amount: parseFloat(amount),
      note,
      isPublic: !!isPublic,
      date: new Date()
    };

    // Инициализируем поля, если их нет
    if (!sender.transactionRequests) sender.transactionRequests = { sent: [], received: [] };
    if (!receiver.transactionRequests) receiver.transactionRequests = { sent: [], received: [] };

    // Обновляем отправителя
    await db.collection('users').updateOne(
      { _id: new ObjectId(senderId) },
      { $push: { 'transactionRequests.sent': requestObjForSender } }
    );

    // Обновляем получателя
    await db.collection('users').updateOne(
      { _id: receiver._id },
      { $push: { 'transactionRequests.received': requestObjForReceiver } }
    );

    return res.status(200).json({ message: 'Money request sent successfully' });
  } catch (error) {
    console.error('Error requesting money:', error);
    return res.status(500).json({ message: 'Internal server error' });
  }
});

app.post('/api/transactions/send', verifyToken, async (req, res) => {
  try {
    const { recipient, amount, note, isPublic } = req.body;
    const senderId = req.user.userId;

    if (!recipient || !amount || isNaN(amount)) {
      return res.status(400).json({ message: 'Invalid input' });
    }

    const parsedAmount = parseFloat(amount);

    const sender = await db.collection('users').findOne({ _id: new ObjectId(senderId) });
    if (!sender) return res.status(404).json({ message: 'Sender not found' });

    if (sender.username === recipient) {
      return res.status(400).json({ message: 'You cannot send money to yourself' });
    }

    const receiver = await db.collection('users').findOne({ username: recipient });
    if (!receiver) return res.status(404).json({ message: 'Recipient not found' });

    if (sender.balance < parsedAmount) {
      return res.status(400).json({ message: 'Insufficient balance' });
    }

    // Обновление баланса
    await db.collection('users').updateOne(
      { _id: sender._id },
      { $inc: { balance: -parsedAmount } }
    );

    await db.collection('users').updateOne(
      { _id: receiver._id },
      { $inc: { balance: parsedAmount } }
    );

    const date = new Date();

    // Транзакции
    const senderTransaction = {
      type: 'transfer',
      role: 'sender',
      from: senderId,
      to: receiver._id.toString(),
      amount: parsedAmount,
      note,
      isPublic: !!isPublic,
      date,
    };

    const receiverTransaction = {
      type: 'transfer',
      role: 'receiver',
      from: senderId,
      to: receiver._id.toString(),
      amount: parsedAmount,
      note,
      isPublic: !!isPublic,
      date,
    };

    // Сохраняем в глобальную коллекцию (по желанию)
    await db.collection('transactions').insertMany([
      senderTransaction,
      receiverTransaction,
    ]);

    // ✅ Добавляем в `users.transactions`
    await db.collection('users').updateOne(
      { _id: sender._id },
      { $push: { transactions: senderTransaction } }
    );

    await db.collection('users').updateOne(
      { _id: receiver._id },
      { $push: { transactions: receiverTransaction } }
    );

    return res.status(200).json({ message: 'Transfer successful' });
  } catch (error) {
    console.error('Error sending money:', error);
    return res.status(500).json({ message: 'Internal server error' });
  }
});

app.get('/api/users/username/:id', verifyToken, async (req, res) => {
  try {
    const userId = req.params.id;

    const user = await db.collection('users').findOne(
      { _id: new ObjectId(userId) },
      { projection: { username: 1 } } // Только username
    );

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    return res.status(200).json({ username: user.username });
  } catch (error) {
    console.error('Ошибка получения username:', error);
    return res.status(500).json({ message: 'Internal server error' });
  }
});

app.get('/api/feed', verifyToken, async (req, res) => {
  try {
    const currentUserId = req.user.userId;

    const user = await db.collection('users').findOne({ _id: new ObjectId(currentUserId) });
    if (!user) return res.status(404).json({ message: 'User not found' });

    const friendUsernames = user.friends || [];

    const friends = await db.collection('users')
      .find({ username: { $in: friendUsernames } })
      .toArray();

    let allPublicTransactions = [];

    for (const friend of friends) {
      const publicTransactions = (friend.transactions || []).filter(t => t.isPublic);

      for (const t of publicTransactions) {
        // Получаем fromUsername и toUsername по ID
        const fromUser = await db.collection('users').findOne(
          { _id: new ObjectId(t.from) },
          { projection: { username: 1 } }
        );

        const toUser = await db.collection('users').findOne(
          { _id: new ObjectId(t.to) },
          { projection: { username: 1 } }
        );

        allPublicTransactions.push({
          fromUsername: fromUser?.username || 'unknown',
          toUsername: toUser?.username || 'unknown',
          amount: t.amount,
          note: t.note || '',
          date: t.date,
        });
      }
    }

    allPublicTransactions.sort((a, b) => new Date(b.date) - new Date(a.date));

    res.json(allPublicTransactions);
  } catch (error) {
    console.error('Ошибка получения ленты:', error);
    res.status(500).json({ message: 'Internal server error' });
  }
});



const PORT = process.env.PORT || 4000;

connectToDB().then(() => {
    app.listen(PORT, () => {
        console.log(`Сервер запущен на порту ${PORT}`);
    });
}).catch((err) => {
    console.error('Ошибка подключения к БД:', err);
    process.exit(1);
});