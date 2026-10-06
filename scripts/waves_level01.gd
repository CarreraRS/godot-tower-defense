class_name WavesLevel01
## ข้อมูล Phase ของฉากที่ 1 — แก้ไขจำนวน/ชนิดศัตรูได้ที่นี่
## enemy = ชื่อไฟล์ใน res://td/data/enemies/  | delay = วินาทีก่อนเริ่มกลุ่ม | interval = ระยะห่างระหว่างตัว

const PHASES: Array = [
	{
		"title": "PHASE 1",
		"subtitle": "หน่วยลาดตระเวนจากประตูมิติ",
		"groups": [
			{"enemy": "soldier", "count": 8, "interval": 1.2, "delay": 0.0},
		],
	},
	{
		"title": "PHASE 2",
		"subtitle": "ยานยนต์หุ้มเกราะเริ่มบุก",
		"groups": [
			{"enemy": "soldier", "count": 12, "interval": 0.9, "delay": 0.0},
			{"enemy": "humvee", "count": 4, "interval": 2.5, "delay": 6.0},
		],
	},
	{
		"title": "PHASE 3",
		"subtitle": "รถถังเหล็กปรากฏตัว — ใช้ Ballista เจาะเกราะ!",
		"groups": [
			{"enemy": "soldier", "count": 12, "interval": 0.8, "delay": 0.0},
			{"enemy": "humvee", "count": 5, "interval": 2.0, "delay": 4.0},
			{"enemy": "tank", "count": 2, "interval": 6.0, "delay": 10.0},
		],
	},
	{
		"title": "PHASE 4",
		"subtitle": "ภัยจากท้องฟ้า — เตรียมหน่วยต่อสู้อากาศยาน!",
		"groups": [
			{"enemy": "helicopter", "count": 5, "interval": 3.0, "delay": 2.0},
			{"enemy": "soldier", "count": 14, "interval": 0.8, "delay": 0.0},
			{"enemy": "humvee", "count": 4, "interval": 2.0, "delay": 12.0},
		],
	},
	{
		"title": "PHASE 5",
		"subtitle": "กองกำลังผสม เจ็ทความเร็วสูงและรถถัง",
		"groups": [
			{"enemy": "tank", "count": 4, "interval": 5.0, "delay": 0.0},
			{"enemy": "jet", "count": 6, "interval": 1.6, "delay": 8.0},
			{"enemy": "humvee", "count": 6, "interval": 1.5, "delay": 3.0},
			{"enemy": "helicopter", "count": 3, "interval": 3.0, "delay": 16.0},
		],
	},
	{
		"title": "BOSS PHASE",
		"subtitle": "เครื่องบินทิ้งระเบิดยักษ์บุกถล่มเมือง!",
		"boss": true,
		"groups": [
			{"enemy": "soldier", "count": 16, "interval": 0.7, "delay": 0.0},
			{"enemy": "tank", "count": 3, "interval": 5.0, "delay": 4.0},
			{"enemy": "helicopter", "count": 4, "interval": 2.5, "delay": 8.0},
			{"enemy": "jet", "count": 6, "interval": 1.2, "delay": 14.0},
			{"enemy": "bomber", "count": 1, "interval": 1.0, "delay": 18.0},
		],
	},
]
