require('dotenv').config({ path: '../.env' });
const express = require('express');
const cors = require('cors');
const { MongoClient, ObjectId } = require('mongodb');
const verifyToken = require('../verifyToken');

const app = express();
app.use(cors());
app.use(express.json());

let db;
(async () => {
    const client = new MongoClient(process.env.MONGO_URI);
    await client.connect();
    db = client.db();
    console.log('User-service connected');
})();

app.get('/:id', verifyToken, async (req, res) => {
    try {
        const userId = req.params.id;
        if (req.user.userId !== userId) return res.status(403).json({ message: 'Forbidden' });
        const user = await db.collection('users').findOne({ _id: new ObjectId(userId) });
        if (!user) return res.status(404).json({ message: 'User not found' });
        const { password, ...userData } = user;
        return res.json(userData);
    } catch (error) {
        console.error('Ошибка получения данных пользователя:', error);
        return res.status(500).json({ message: 'Внутренняя ошибка сервера' });
    }
});

app.post('/remove-card', verifyToken, async (req, res) => {
    try {
        const { cardNumber } = req.body;
        const userId = req.user.userId;
        const user = await db.collection('users').findOne({ _id: new ObjectId(userId) });
        if (!user) return res.status(404).json({ message: 'User not found' });
        const cardIndex = user.cards.findIndex(card => card.cardNumber === cardNumber);
        if (cardIndex === -1) return res.status(400).json({ message: 'Card not found in saved cards' });
        user.cards.splice(cardIndex, 1);
        await db.collection('users').updateOne({ _id: new ObjectId(userId) }, { $set: { cards: user.cards } });
        return res.status(200).json({ message: 'Card removed successfully' });
    } catch (error) {
        console.error('Error removing card:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
});

app.post('/friends-info', verifyToken, async (req, res) => {
    try {
        const { friendsUsernames, receivedUsernames, sentUsernames } = req.body;
        if (!Array.isArray(friendsUsernames) || !Array.isArray(receivedUsernames) || !Array.isArray(sentUsernames)) {
            return res.status(400).json({ message: 'Invalid input data' });
        }

        const friendsDetails = await db.collection('users').find({ username: { $in: friendsUsernames } }).toArray();
        const receivedRequestsDetails = await db.collection('users').find({ username: { $in: receivedUsernames } }).toArray();
        const sentRequestsDetails = await db.collection('users').find({ username: { $in: sentUsernames } }).toArray();

        return res.json({
            friends: friendsDetails.map(u => ({ username: u.username, displayname: u.displayname, avatar: u.avatar })),
            receivedRequests: receivedRequestsDetails.map(u => ({ username: u.username, displayname: u.displayname, avatar: u.avatar })),
            sentRequests: sentRequestsDetails.map(u => ({ username: u.username, displayname: u.displayname, avatar: u.avatar })),
        });
    } catch (error) {
        console.error('Ошибка получения информации о друзьях и запросах:', error);
        return res.status(500).json({ message: 'Внутренняя ошибка сервера' });
    }
});

app.post('/cancel-friend-request', verifyToken, async (req, res) => {
    try {
        const { userId, friendUsername } = req.body;
        const user = await db.collection('users').findOne({ _id: new ObjectId(userId) });
        if (!user) return res.status(404).json({ message: 'User not found' });
        const friend = await db.collection('users').findOne({ username: friendUsername });
        if (!friend) return res.status(404).json({ message: 'Friend not found' });

        user.requests.sent = user.requests.sent.filter(username => username !== friendUsername);
        friend.requests.received = friend.requests.received.filter(username => username !== user.username);

        await db.collection('users').updateOne({ _id: new ObjectId(userId) }, { $set: { 'requests.sent': user.requests.sent } });
        await db.collection('users').updateOne({ username: friendUsername }, { $set: { 'requests.received': friend.requests.received } });

        return res.status(200).json({ message: 'Friend request canceled successfully' });
    } catch (error) {
        console.error('Error canceling friend request:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
});

app.post('/accept-friend-request', verifyToken, async (req, res) => {
    try {
        const { userId, friendUsername } = req.body;
        const user = await db.collection('users').findOne({ _id: new ObjectId(userId) });
        const friend = await db.collection('users').findOne({ username: friendUsername });
        if (!user || !friend) return res.status(404).json({ message: 'User or Friend not found' });

        user.requests.received = user.requests.received.filter(username => username !== friendUsername);
        user.friends.push(friendUsername);
        friend.requests.sent = friend.requests.sent.filter(username => username !== user.username);
        friend.friends.push(user.username);

        await db.collection('users').updateOne({ _id: new ObjectId(userId) }, { $set: { 'requests.received': user.requests.received, friends: user.friends } });
        await db.collection('users').updateOne({ _id: new ObjectId(friend._id) }, { $set: { 'requests.sent': friend.requests.sent, friends: friend.friends } });

        return res.status(200).json({ message: 'Friend request accepted successfully' });
    } catch (error) {
        console.error('Error accepting friend request:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
});

app.post('/decline-friend-request', verifyToken, async (req, res) => {
    try {
        const { userId, friendUsername } = req.body;
        const user = await db.collection('users').findOne({ _id: new ObjectId(userId) });
        const friend = await db.collection('users').findOne({ username: friendUsername });
        if (!user || !friend) return res.status(404).json({ message: 'User or Friend not found' });

        user.requests.received = user.requests.received.filter(username => username !== friendUsername);
        friend.requests.sent = friend.requests.sent.filter(username => username !== user.username);

        await db.collection('users').updateOne({ _id: new ObjectId(userId) }, { $set: { 'requests.received': user.requests.received } });
        await db.collection('users').updateOne({ _id: new ObjectId(friend._id) }, { $set: { 'requests.sent': friend.requests.sent } });

        return res.status(200).json({ message: 'Friend request declined successfully' });
    } catch (error) {
        console.error('Error declining friend request:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
});

app.post('/delete-friend', verifyToken, async (req, res) => {
    try {
        const { userId, friendUsername } = req.body;
        if (req.user.userId !== userId) return res.status(403).json({ message: 'Forbidden' });

        const user = await db.collection('users').findOne({ _id: new ObjectId(userId) });
        const friend = await db.collection('users').findOne({ username: friendUsername });
        if (!user || !friend) return res.status(404).json({ message: 'User or Friend not found' });

        user.friends = user.friends.filter(friend => friend !== friendUsername);
        friend.friends = friend.friends.filter(friend => friend !== user.username);
        user.requests.sent = user.requests.sent.filter(username => username !== friendUsername);
        friend.requests.received = friend.requests.received.filter(username => username !== user.username);

        await db.collection('users').updateOne({ _id: new ObjectId(userId) }, { $set: { friends: user.friends, 'requests.sent': user.requests.sent } });
        await db.collection('users').updateOne({ _id: new ObjectId(friend._id) }, { $set: { friends: friend.friends, 'requests.received': friend.requests.received } });

        return res.status(200).json({ message: 'Friend successfully removed' });
    } catch (error) {
        console.error('Error removing friend:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
});

app.post('/username-info', verifyToken, async (req, res) => {
    try {
        const { username } = req.body;
        const currentUsername = req.user.username;
        if (!username) return res.status(400).json({ message: 'Username is required' });
        const user = await db.collection('users').findOne({ username });
        if (!user) return res.status(404).json({ message: 'User not found' });
        if (username == currentUsername) return res.status(400).json({ message: 'You can\'t send money to yourself' });
        const { password, ...safeUser } = user;
        return res.status(200).json({ username: safeUser.username, displayname: safeUser.displayname, avatar: safeUser.avatar });
    } catch (error) {
        console.error('Ошибка получения инфо по username:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
});

app.get('/username/:id', verifyToken, async (req, res) => {
    try {
        const userId = req.params.id;
        const user = await db.collection('users').findOne({ _id: new ObjectId(userId) }, { projection: { username: 1 } });
        if (!user) return res.status(404).json({ message: 'User not found' });
        return res.status(200).json({ username: user.username });
    } catch (error) {
        console.error('Ошибка получения username:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
});

app.listen(4002, () => console.log('User-service на порту 4002'));
