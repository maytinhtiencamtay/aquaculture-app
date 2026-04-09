const bcrypt = require('bcryptjs');
const fs = require('fs');
const path = require('path');

(async () => {
  const dataPath = path.join(__dirname, 'data', 'data.json');
  
  // Ensure data directory exists
  const dataDir = path.dirname(dataPath);
  if (!fs.existsSync(dataDir)) {
    fs.mkdirSync(dataDir, { recursive: true });
  }
  
  const data = JSON.parse(fs.readFileSync(dataPath, 'utf8'));
  
  const newPassword = '123456';
  const hashed = await bcrypt.hash(newPassword, 10);
  
  let found = false;
  for (const emp of data.employees) {
    if (emp.email === 'ngthihanh2011@gmail.com') {
      emp.password = hashed;
      found = true;
      console.log('Reset password for:', emp.email, '-> 123456');
      break;
    }
  }
  
  if (!found) {
    console.log('User not found!');
    return;
  }
  
  fs.writeFileSync(dataPath, JSON.stringify(data, null, 2));
  console.log('Done! Saved to data.json');
})();
