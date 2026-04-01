const bcrypt = require('bcryptjs');
const hash = '$2a$10$cgytsNAsi7w66FxDiNFF6e7vWhacQsPVeWrjDk/E3DGA3CCFi4UsG';
const candidates = ['123456', 'admin123', 'password', 'aqua123', 'admin', '12345678', 'Abc123', 'admin@123', 'test', 'test123', 'Test123', 'testfarm', '111111', 'abc123', 'qwerty', '1234567890'];
(async () => {
  for (const p of candidates) {
    const ok = await bcrypt.compare(p, hash);
    console.log(p, '->', ok);
    if (ok) { console.log('FOUND:', p); break; }
  }
})();
