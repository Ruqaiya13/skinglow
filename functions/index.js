const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');

admin.initializeApp();

// إعداد Gmail مباشرة - مجاني 100%
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'oorro137@gmail.com',
    pass: 'balizorkuwrhumuw'
  }
});

// دالة ترسل إيميل عندما يضاف كود جديد
exports.onNewVerificationCode = functions.database
  .ref('/verifications/{userId}')
  .onCreate(async (snapshot, context) => {
    try {
      const { email, code } = snapshot.val();

      console.log('🚀 إرسال إيميل إلى:', email);
      console.log('🔢 الكود:', code);

      const mailOptions = {
        from: '"Skinglow" <oorro137@gmail.com>',
        to: email,
        subject: 'كود التحقق - Skinglow',
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <div style="background: #914D74; color: white; padding: 20px; text-align: center;">
              <h1>Skinglow</h1>
              <h2>كود التحقق</h2>
            </div>
            <div style="background: white; padding: 30px;">
              <p>مرحباً!</p>
              <p>كود التحقق الخاص بك هو:</p>
              <div style="background: #f8f8f8; padding: 20px; text-align: center; margin: 20px 0; font-size: 32px; font-weight: bold; color: #914D74;">
                ${code}
              </div>
              <p>هذا الكود صالح لمدة 10 دقائق</p>
            </div>
          </div>
        `
      };

      await transporter.sendMail(mailOptions);
      console.log('✅ تم إرسال الإيميل بنجاح إلى:', email);
      return null;

    } catch (error) {
      console.error('❌ خطأ في الإرسال:', error);
      return null;
    }
  });