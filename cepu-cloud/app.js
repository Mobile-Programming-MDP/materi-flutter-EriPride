require('dotenv').config();

const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const admin = require('firebase-admin');

const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const app = express();

app.use(cors());
app.use(bodyParser.json());


// =====================================
// SEND TO DEVICE
// =====================================
app.post('/send-to-device', async (req, res) => {
  try {

    const { token, title, body } = req.body;

    const message = {
      notification: {
        title,
        body,
      },
      token,
    };

    const response = await admin.messaging().send(message);

    res.status(200).json({
      success: true,
      response,
    });

  } catch (error) {

    res.status(500).json({
      success: false,
      error: error.message,
    });

  }
});


// =====================================
// SEND TO TOPIC
// =====================================
app.post('/send-to-topic', async (req, res) => {
  try {

    const { topic, title, body } = req.body;

    const message = {
      notification: {
        title,
        body,
      },
      topic,
    };

    const response = await admin.messaging().send(message);

    res.status(200).json({
      success: true,
      response,
    });

  } catch (error) {

    res.status(500).json({
      success: false,
      error: error.message,
    });

  }
});


// =====================================
// SEND TO MULTIPLE
// =====================================
app.post('/send-to-multiple', async (req, res) => {
  try {

    const { tokens, title, body } = req.body;

    const message = {
      notification: {
        title,
        body,
      },
      tokens,
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    res.status(200).json({
      success: true,
      response,
    });

  } catch (error) {

    res.status(500).json({
      success: false,
      error: error.message,
    });

  }
});

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});