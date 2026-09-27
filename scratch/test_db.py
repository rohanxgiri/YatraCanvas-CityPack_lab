import sqlite3

conn = sqlite3.connect('assets/city_packs/jaipur/yatracanvas.db')
rows = conn.execute('''
SELECT 
  category, 
  COUNT(*) as total,
  SUM(CASE WHEN primary_image_path IS NOT NULL AND primary_image_path != '' THEN 1 ELSE 0 END) as with_images,
  SUM(CASE WHEN opening_hours IS NOT NULL AND opening_hours != '' THEN 1 ELSE 0 END) as with_hours,
  SUM(CASE WHEN latitude IS NOT NULL AND longitude IS NOT NULL AND latitude != 0 AND longitude != 0 THEN 1 ELSE 0 END) as with_geo,
  SUM(CASE WHEN (website IS NOT NULL AND website != '') OR (phone IS NOT NULL AND phone != '') THEN 1 ELSE 0 END) as with_details
FROM places
WHERE city_id = 'jaipur'
GROUP BY category
ORDER BY total DESC
''').fetchall()

for r in rows:
    print(r)
