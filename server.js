const express = require("express");
const bodyParser = require("body-parser");
const cors = require("cors");
const admin = require("firebase-admin");
const cron = require("node-cron");

const serviceAccount = require("./qataar-f48c7-127054c57832.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const app = express();
app.use(cors());
app.use(bodyParser.json());

const db = admin.firestore();

/* ---------------------------
   1️⃣ Booking Endpoint (saves to Firestore)
---------------------------- */
app.post("/bookings", async (req, res) => {
  try {
    const {
      userId,
      serviceName,
      branchId,
      serviceId,
      branchName,
      categoryId,
      categoryName,
      city,
      fcmToken,
    } = req.body;

    if (!fcmToken) {
      return res.status(400).json({ success: false, message: "Missing FCM token" });
    }

    const dateStr = new Date().toISOString().split('T')[0];
    const bookingsCollection = db.collection('tokens').doc(dateStr).collection('bookings');

    // Automatically assign next token number per service
    const lastTokenSnapshot = await bookingsCollection
      .where("serviceId", "==", serviceId)
      .orderBy("tokenNumber", "desc")
      .limit(1)
      .get();

    let newTokenNumber = 1;
    if (!lastTokenSnapshot.empty) {
      newTokenNumber = lastTokenSnapshot.docs[0].data().tokenNumber + 1;
    }

    const bookingRef = bookingsCollection.doc();

    await bookingRef.set({
      userId,
      serviceName,
      serviceId,
      branchId,
      branchName,
      categoryId,
      categoryName,
      city,
      fcmToken,
      tokenNumber: newTokenNumber,
      status: 'booked',
      notified: false,
      notifiedApproaching: false,
      notifiedTurn: false,
      bookingTime: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Increment dailyTokenCounter in services doc
    const serviceRef = db.collection('categories').doc(categoryId).collection('branches').doc(branchId).collection('services').doc(serviceId);
    await serviceRef.set({ dailyTokenCounter: admin.firestore.FieldValue.increment(1) }, { merge: true });

    // Send Booking Confirmed Notification
    const message = {
      token: fcmToken,
      notification: {
        title: "Booking Confirmed!",
        body: `Your token ${newTokenNumber} is booked for ${serviceName} at ${branchName}.`,
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
    };
    await admin.messaging().send(message);
    await bookingRef.update({ notified: true });

    res.status(200).json({
      success: true,
      message: "Booking saved and notification sent.",
      tokenNumber: newTokenNumber,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: err.toString() });
  }
});

/* ---------------------------
   2️⃣ Send Notification Only (no Firestore save)
---------------------------- */
app.post("/sendNotification", async (req, res) => {
  try {
    const { fcmToken, tokenNumber, serviceName, branchName } = req.body;

    if (!fcmToken) {
      return res.status(400).json({ success: false, message: "Missing FCM token" });
    }

    // Send Booking Confirmed Notification
    const message = {
      token: fcmToken,
      notification: {
        title: "Booking Confirmed!",
        body: `Your token ${tokenNumber} is booked for ${serviceName} at ${branchName}.`,
      },
      data: {
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
    };
    await admin.messaging().send(message);

    res.status(200).json({
      success: true,
      message: "Notification sent successfully.",
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: err.toString() });
  }
});

/* ---------------------------
   2️⃣ Update Current Token
---------------------------- */
app.post("/updateToken", async (req, res) => {
  const { categoryId, branchId, serviceId, currentToken } = req.body;
  try {
    const serviceRef = db.collection('categories').doc(categoryId).collection('branches').doc(branchId).collection('services').doc(serviceId);
    await serviceRef.set({ currentToken }, { merge: true });
    res.status(200).json({ success: true, message: "Current token updated" });
  } catch (err) {
    console.error(err);
    res.status(500).json({ success: false, error: err.toString() });
  }
});

/* ---------------------------
   3️⃣ Cron Job: Turn Approaching & Your Turn
---------------------------- */
cron.schedule("* * * * *", async () => {
  try {
    console.log("🔄 Cron job running...");
    const todayStr = new Date().toISOString().split('T')[0];
    const categoriesSnapshot = await db.collection('categories').get();

    for (const categoryDoc of categoriesSnapshot.docs) {
      const categoryId = categoryDoc.id;
      const branchesSnapshot = await db.collection('categories').doc(categoryId).collection('branches').get();

      for (const branchDoc of branchesSnapshot.docs) {
        const branchId = branchDoc.id;
        const servicesSnapshot = await db.collection('categories').doc(categoryId).collection('branches').doc(branchId).collection('services').get();

        for (const serviceDoc of servicesSnapshot.docs) {
          const serviceData = serviceDoc.data();
          const currentToken = serviceData.currentToken || 0;
          const serviceId = serviceDoc.id;

          console.log(`📍 Checking service ${serviceId} in branch ${branchId}, category ${categoryId}, currentToken: ${currentToken}`);

          const bookingsRef = db.collection('tokens').doc(todayStr)
            .collection('bookings')
            .where("serviceId", "==", serviceId)
            .where("branchId", "==", branchId)
            .where("categoryId", "==", categoryId);

          const snapshot = await bookingsRef.get();

          for (const doc of snapshot.docs) {
            const booking = doc.data();

            if (booking.tokenNumber <= currentToken) continue;

            console.log(`🎫 Checking booking token ${booking.tokenNumber}, notifiedTurn: ${booking.notifiedTurn}`);

            // Turn Approaching (2 tokens away)
            if (!booking.notifiedApproaching && booking.tokenNumber - currentToken === 2) {
              console.log(`📢 Sending 'Your Turn is Near!' to token ${booking.tokenNumber}`);
              const msg = {
                token: booking.fcmToken,
                notification: {
                  title: "Your Turn is Near!",
                  body: `Token ${booking.tokenNumber} will be called soon at ${booking.branchName}.`,
                },
                data: {
                  click_action: "FLUTTER_NOTIFICATION_CLICK",
                },
              };
              await admin.messaging().send(msg);
              await doc.ref.update({ notifiedApproaching: true });
            }

            // Your Turn (next token)
            if (!booking.notifiedTurn && booking.tokenNumber === currentToken + 1) {
              console.log(`🚨 Sending 'It's Your Turn!' to token ${booking.tokenNumber}`);
              const msg = {
                token: booking.fcmToken,
                notification: {
                  title: "It's Your Turn!",
                  body: `Please prepare. Your token ${booking.tokenNumber} is next to be served at ${booking.branchName}.`,
                },
                data: {
                  click_action: "FLUTTER_NOTIFICATION_CLICK",
                },
              };
              await admin.messaging().send(msg);
              await doc.ref.update({ notifiedTurn: true });
            }
          }
        }
      }
    }
    console.log("✅ Cron job completed");
  } catch (err) {
    console.error("❌ Cron job error:", err);
  }
});

/* ---------------------------
   4️⃣ Start Server
---------------------------- */
const PORT = 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));

/* ---------------------------
   5️⃣ Optional: Update User Token Endpoint
---------------------------- */
app.post("/updateTokenForUser", async (req, res) => {
  const { userId, fcmToken } = req.body;
  if (!userId || !fcmToken) return res.status(400).send("Missing userId or token");

  await db.collection("users").doc(userId).set({ fcmToken }, { merge: true });
  res.send("Token updated");
});
