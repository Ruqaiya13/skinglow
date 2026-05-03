const nodemailer = require('nodemailer');

// إعداد الإيميل - ضع إعداداتك هنا
const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'oorro137@gmail.com', // غير هذا ببريدك
    pass: 'balizorkuwrhumuw'     // غير هذا ب App Password
  }
});

// دالة إرسال كود التحقق
const sendVerificationCode = async (userEmail, verificationCode) => {
  try {
    const mailOptions = {
      from: '"Skinglow" <your-email@gmail.com>',
      to: userEmail,
      subject: 'كود التحقق - Skinglow',
      html: `
        <div style="font-family: Arial, sans-serif; text-align: center;">
          <h2 style="color: #333;">مرحباً بك في Skinglow! 🌟</h2>
          <p>استخدم الكود التالي للتحقق من حسابك:</p>
          <div style="background: #f0f0f0; padding: 15px; margin: 20px 0; font-size: 24px; font-weight: bold; letter-spacing: 5px;">
            ${verificationCode}
          </div>
          <p>هذا الكود صالح لمدة 10 دقائق</p>
        </div>
      `
    };

    const result = await transporter.sendMail(mailOptions);
    console.log('✅ تم إرسال الكود إلى:', userEmail);
    return { success: true, messageId: result.messageId };

  } catch (error) {
    console.error('❌ خطأ في إرسال الإيميل:', error);
    return { success: false, error: error.message };
  }
};

// صدر الدالة علشان نستخدمها في其他地方
module.exports = { sendVerificationCode };

