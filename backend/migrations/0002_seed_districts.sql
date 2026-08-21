-- Sri Lankan districts → 2-letter area codes for batch numbers.
-- Cinnamon-growing districts prioritized; all 25 districts included.
CREATE TABLE IF NOT EXISTS districts (
  area_code CHAR(2) PRIMARY KEY,
  name_en   TEXT NOT NULL,
  name_si   TEXT NOT NULL,
  province  TEXT NOT NULL
);

INSERT INTO districts (area_code, name_en, name_si, province) VALUES
  ('GM', 'Galle',            'ගාල්ල',          'Southern'),
  ('MA', 'Matara',           'මාතර',           'Southern'),
  ('HB', 'Hambantota',       'හම්බන්තොට',       'Southern'),
  ('KN', 'Kandy',            'මහනුවර',          'Central'),
  ('ML', 'Matale',           'මාතලේ',           'Central'),
  ('NU', 'Nuwara Eliya',     'නුවරඑළිය',        'Central'),
  ('CO', 'Colombo',          'කොළඹ',            'Western'),
  ('GA', 'Gampaha',          'ගම්පහ',            'Western'),
  ('KL', 'Kalutara',         'කළුතර',           'Western'),
  ('JA', 'Jaffna',           'යාපනය',           'Northern'),
  ('KI', 'Kilinochchi',      'කිලිනොච්චිය',      'Northern'),
  ('MN', 'Mannar',           'මන්නාරම',          'Northern'),
  ('VA', 'Vavuniya',         'වව්නියාව',         'Northern'),
  ('MU', 'Mullaitivu',       'මුලතිව්',          'Northern'),
  ('BT', 'Batticaloa',       'මඩකලපුව',         'Eastern'),
  ('AM', 'Ampara',           'අම්පාර',           'Eastern'),
  ('TR', 'Trincomalee',      'ත්‍රිකුණාමලය',      'Eastern'),
  ('KM', 'Kurunegala',       'කුරුණෑගල',         'North Western'),
  ('PU', 'Puttalam',         'පුත්තලම',          'North Western'),
  ('AN', 'Anuradhapura',     'අනුරාධපුරය',      'North Central'),
  ('PO', 'Polonnaruwa',      'පොළොන්නරුව',      'North Central'),
  ('BD', 'Badulla',          'බදුල්ල',           'Uva'),
  ('MO', 'Monaragala',       'මොණරාගල',          'Uva'),
  ('RA', 'Ratnapura',        'රත්නපුරය',         'Sabaragamuwa'),
  ('KE', 'Kegalle',          'කෑගල්ල',           'Sabaragamuwa')
ON CONFLICT (area_code) DO NOTHING;
