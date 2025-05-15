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
    console.log('Transaction-service connected');
})();

app.post('/deposit', verifyToken, async (req, res) => {
    try {
        const { userId, amount, isSaved, cardNumber, expirationMonth, expirationYear, cvv, cardHolder } = req.body;
        if (amount <= 0) return res.status(400).json({ message: 'Amount must be greater than 0' });
        if (expirationMonth <= 0 || expirationMonth > 12) return res.status(400).json({ message: 'Please enter a valid month' });
        if (expirationYear == 25 && expirationMonth <= 5) return res.status(400).json({ message: 'Please enter a valid expiration date' });
        if (expirationYear < 25) return res.status(400).json({ message: 'Please enter a valid year' });

        const user = await db.collection('users').findOne({ _id: new ObjectId(userId) });
        if (!user) return res.status(404).json({ message: 'User not found' });

        let updatedBalance = user.balance;

        if (isSaved) {
            const existingCard = user.cards.find(card => card.cardNumber === cardNumber);
            if (!existingCard) {
                await db.collection('users').updateOne(
                    { _id: new ObjectId(userId) },
                    {
                        $push: {
                            cards: {
                                cardNumber, expirationMonth, expirationYear, cvv, cardHolder, createdAt: new Date()
                            }
                        }
                    }
                );
            }
        }

        updatedBalance += amount;
        await db.collection('users').updateOne(
            { _id: new ObjectId(userId) },
            { $set: { balance: updatedBalance } }
        );

        const transaction = {
            type: 'deposit',
            to: userId,
            from: cardNumber,
            amount,
            date: new Date(),
            message: '',
            isPublic: false,
            role: 'receiver'
        };

        await db.collection('users').updateOne(
            { _id: new ObjectId(userId) },
            { $push: { transactions: transaction } }
        );

        return res.status(200).json({ message: 'Deposit successful', newBalance: updatedBalance });
    } catch (error) {
        console.error('Error processing deposit:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
});

app.post('/withdraw', verifyToken, async (req, res) => {
    try {
        const { userId, amount, cardNumber, cardHolder } = req.body;
        if (amount <= 0) return res.status(400).json({ message: 'Amount must be greater than 0' });
        const user = await db.collection('users').findOne({ _id: new ObjectId(userId) });
        if (!user) return res.status(404).json({ message: 'User not found' });
        let updatedBalance = user.balance;
        if (updatedBalance < amount) return res.status(400).json({ message: 'Insufficient balance' });
        updatedBalance -= amount;
        await db.collection('users').updateOne(
            { _id: new ObjectId(userId) },
            { $set: { balance: updatedBalance } }
        );
        const transaction = {
            type: 'withdrawal',
            to: cardNumber,
            from: userId,
            amount,
            date: new Date(),
            message: '',
            isPublic: false,
            role: 'sender'
        };
        await db.collection('users').updateOne(
            { _id: new ObjectId(userId) },
            { $push: { transactions: transaction } }
        );
        return res.status(200).json({ message: 'Withdrawal successful', newBalance: updatedBalance });
    } catch (error) {
        console.error('Error processing withdrawal:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
});

app.post('/request', verifyToken, async (req, res) => {
    try {
        const { recipient, amount, note, isPublic } = req.body;
        const senderId = req.user.userId;
        if (!recipient || !amount || isNaN(amount)) return res.status(400).json({ message: 'Invalid input' });
        const sender = await db.collection('users').findOne({ _id: new ObjectId(senderId) });
        if (!sender) return res.status(404).json({ message: 'Sender not found' });
        if (sender.username === recipient) return res.status(400).json({ message: 'You can\'t request money from yourself' });
        const receiver = await db.collection('users').findOne({ username: recipient });
        if (!receiver) return res.status(404).json({ message: 'Recipient not found' });

        const requestObjForSender = { to: recipient, amount: parseFloat(amount), note, isPublic: !!isPublic, date: new Date() };
        const requestObjForReceiver = { from: sender.username, amount: parseFloat(amount), note, isPublic: !!isPublic, date: new Date() };

        if (!sender.transactionRequests) sender.transactionRequests = { sent: [], received: [] };
        if (!receiver.transactionRequests) receiver.transactionRequests = { sent: [], received: [] };

        await db.collection('users').updateOne(
            { _id: new ObjectId(senderId) },
            { $push: { 'transactionRequests.sent': requestObjForSender } }
        );
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

app.post('/send', verifyToken, async (req, res) => {
    try {
        const { recipient, amount, note, isPublic } = req.body;
        const senderId = req.user.userId;
        if (!recipient || !amount || isNaN(amount)) return res.status(400).json({ message: 'Invalid input' });
        const parsedAmount = parseFloat(amount);

        const sender = await db.collection('users').findOne({ _id: new ObjectId(senderId) });
        if (!sender) return res.status(404).json({ message: 'Sender not found' });
        if (sender.username === recipient) return res.status(400).json({ message: 'You cannot send money to yourself' });
        const receiver = await db.collection('users').findOne({ username: recipient });
        if (!receiver) return res.status(404).json({ message: 'Recipient not found' });
        if (sender.balance < parsedAmount) return res.status(400).json({ message: 'Insufficient balance' });

        await db.collection('users').updateOne({ _id: sender._id }, { $inc: { balance: -parsedAmount } });
        await db.collection('users').updateOne({ _id: receiver._id }, { $inc: { balance: parsedAmount } });

        const date = new Date();
        const senderTransaction = { type: 'transfer', role: 'sender', from: senderId, to: receiver._id.toString(), amount: parsedAmount, note, isPublic: !!isPublic, date };
        const receiverTransaction = { type: 'transfer', role: 'receiver', from: senderId, to: receiver._id.toString(), amount: parsedAmount, note, isPublic: !!isPublic, date };

        await db.collection('transactions').insertMany([senderTransaction, receiverTransaction]);
        await db.collection('users').updateOne({ _id: sender._id }, { $push: { transactions: senderTransaction } });
        await db.collection('users').updateOne({ _id: receiver._id }, { $push: { transactions: receiverTransaction } });

        return res.status(200).json({ message: 'Transfer successful' });
    } catch (error) {
        console.error('Error sending money:', error);
        return res.status(500).json({ message: 'Internal server error' });
    }
});

app.listen(4003, () => console.log('Transaction-service на порту 4003'));
