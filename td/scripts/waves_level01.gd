class_name WavesLevel01
## ข้อมูลโหมดเนื้อเรื่อง: Phase ของศัตรู + บทพูด/คัตซีน — แก้ไขได้ที่นี่
## enemy = ชื่อไฟล์ใน res://td/data/enemies/  | delay = วินาทีก่อนเริ่มกลุ่ม | interval = ระยะห่างระหว่างตัว
## line = บทพูดสั้นตอนเริ่มเฟส | interlude = คัตซีนหลังผ่านเฟสก่อนหน้า (ก่อนเริ่มเฟสนี้)
## บรรทัดคัตซีน: who = king/advisor/scout/hero/narrator | focus = gate/castle/field/boss | action = ชื่อเหตุการณ์

const INTRO: Array = [
	{"who": "narrator", "focus": "field", "text": "อาณาจักรเอลวาเรน... ยามเช้าที่แสนสงบสุขของเมืองหลวง"},
	{"who": "narrator", "focus": "gate", "action": "gate_open", "text": "ทันใดนั้น! แผ่นดินสั่นสะเทือน ประตูยักษ์ปริศนาผุดขึ้นกลางทุ่งหน้าเมือง"},
	{"who": "scout", "focus": "gate", "text": "รายงาน! มีประตูประหลาดโผล่ขึ้นมาหน้าเมือง แสงสีม่วงพวยพุ่งออกมาไม่หยุด!"},
	{"who": "king", "focus": "castle", "text": "ท่านแม่ทัพ! จงนำกองทัพไปเฝ้าระวังรอบประตูนั้นเดี๋ยวนี้ อย่าให้สิ่งใดผ่านเข้ามาถึงเมืองได้!"},
	{"who": "advisor", "focus": "field", "text": "วางกำลังพลไว้สองข้างถนนเถิดท่าน... ข้ารู้สึกได้ว่ามีบางอย่างกำลังจะออกมาจากประตูนั่น"},
]

const HERO_SUMMON: Array = [
	{"who": "narrator", "focus": "boss", "text": "เสียงไซเรนโหยหวนดังก้องมาจากอีกฟากของประตู... แล้วเงาทะมึนขนาดมหึมาก็คืบคลานออกมา"},
	{"who": "king", "focus": "castle", "text": "เสียงประหลาดนั่นมันอะไรกัน!? ...สัตว์ประหลาดเหล็กตัวนั้นใหญ่เกินกว่ากองทัพเราจะรับไหว"},
	{"who": "king", "focus": "castle", "text": "ไม่ได้การแล้ว! เหล่านักบวช เริ่มพิธีกรรมอัญเชิญผู้กล้าเดี๋ยวนี้!"},
	{"who": "narrator", "focus": "castle", "action": "ritual", "text": "แสงศักดิ์สิทธิ์พุ่งทะยานจากยอดปราสาท ท้องฟ้าแยกออกเป็นสองฝั่ง..."},
	{"who": "hero", "focus": "castle", "text": "ข้า อาเรียน ผู้กล้าแห่งแสงสวรรค์ ตอบรับคำเรียกขาน! ท่านแม่ทัพ ส่งข้าไปยังแนวหน้าเถิด!"},
]

const ENDING: Array = [
	{"who": "narrator", "focus": "gate", "action": "gate_close", "text": "อสูรเหล็กแห่งฟากฟ้าร่วงลงสู่พื้นดิน... พลังของผู้กล้าทำให้ประตูมิติระเบิดและสลายหายไป!"},
	{"who": "king", "focus": "castle", "text": "เจ้าทำได้ดีมาก ท่านแม่ทัพ! ชื่อของเจ้าจะถูกจารึกไว้ในประวัติศาสตร์ของเอลวาเรนตลอดไป"},
	{"who": "hero", "focus": "gate", "text": "ประตูถูกทำลายแล้ว... แต่โลกอีกฝั่งยังอยู่ สักวันพวกมันอาจหาทางกลับมาอีก จงเตรียมพร้อมไว้"},
]

const DEFEAT: Array = [
	{"who": "scout", "focus": "castle", "text": "กำแพงเมืองแตกแล้ว! พวกมันบุกเข้ามาในเมือง!"},
	{"who": "narrator", "focus": "castle", "action": "castle_fall", "text": "เสียงระเบิดดังกึกก้อง... ปราสาทแห่งเอลวาเรนพังทลายลงต่อหน้าต่อตา"},
	{"who": "king", "focus": "castle", "text": "ไม่นะ... เมืองหลวงของข้า... ประชาชนของข้า... อภัยให้ข้าด้วย"},
	{"who": "narrator", "focus": "field", "text": "อาณาจักรเอลวาเรนตกอยู่ภายใต้เงาของประตูมิติ... แต่ประวัติศาสตร์ยังเขียนใหม่ได้เสมอ"},
]

const DEFEAT_ENDLESS: Array = [
	{"who": "narrator", "focus": "castle", "action": "castle_fall", "text": "กำแพงเมืองแตก! ปราสาทพังทลายลงหลังการต่อสู้อันยาวนาน..."},
]

const PHASES: Array = [
	{
		"title": "PHASE 1",
		"subtitle": "หน่วยลาดตระเวนจากประตูมิติ",
		"line": "ทหารพวกนั้นกำลังเดินแถวมาตามถนน! เตรียมรับมือ!",
		"groups": [
			{"enemy": "soldier", "count": 8, "interval": 1.3, "delay": 0.0},
		],
	},
	{
		"title": "PHASE 2",
		"subtitle": "รถม้าเหล็กไร้ม้าเริ่มบุก",
		"interlude": [
			{"who": "scout", "focus": "gate", "text": "พวกมันสวมชุดลายพราง ถือท่อนเหล็กที่พ่นไฟได้... พวกนั้นมันอะไรกัน!?"},
			{"who": "king", "focus": "castle", "action": "gold", "text": "ไม่ว่าพวกมันเป็นใคร ก็อย่าหวังจะแตะต้องเมืองของข้า! เพิ่มการเฝ้าระวัง และส่งทองสนับสนุนไปให้แม่ทัพ!"},
			{"who": "advisor", "focus": "field", "text": "หน่วยสอดแนมเห็นรถเหล็กไร้ม้ากำลังเคลื่อนมา พวกมันเร็วมาก ใช้นักปรุงยาปาระเบิดใส่เป็นกลุ่มเถิด"},
		],
		"line": "รถเหล็กมาแล้ว! อย่าให้หลุดถึงประตูเมือง!",
		"groups": [
			{"enemy": "soldier", "count": 12, "interval": 1.0, "delay": 0.0},
			{"enemy": "humvee", "count": 4, "interval": 2.5, "delay": 6.0},
		],
	},
	{
		"title": "PHASE 3",
		"subtitle": "ป้อมเหล็กเคลื่อนที่ปรากฏตัว!",
		"interlude": [
			{"who": "advisor", "focus": "gate", "text": "รถเหล็กพวกนั้นทนกว่าที่คิด... และได้ยินว่ามีป้อมเหล็กเคลื่อนที่ได้กำลังตามมาอีก"},
			{"who": "king", "focus": "castle", "action": "gold", "text": "ระดมช่างและนักเล่นแร่แปรธาตุทั้งเมือง! ส่งทองไปให้แม่ทัพเพิ่มอีก"},
			{"who": "advisor", "focus": "field", "text": "โกเลมและนักบุญโจมตีเจาะเกราะได้ และอย่าลืมสั่งใช้ทักษะพิเศษของแต่ละหน่วย (คลิกยูนิตแล้วกด F)"},
		],
		"line": "ป้อมเหล็กมาแล้ว! ใช้พลังที่เจาะเกราะได้!",
		"groups": [
			{"enemy": "soldier", "count": 12, "interval": 0.9, "delay": 0.0},
			{"enemy": "humvee", "count": 4, "interval": 2.2, "delay": 5.0},
			{"enemy": "tank", "count": 2, "interval": 7.0, "delay": 10.0},
		],
	},
	{
		"title": "PHASE 4",
		"subtitle": "ภัยจากท้องฟ้า — นกเหล็กบินตามแนวถนน",
		"interlude": [
			{"who": "scout", "focus": "gate", "text": "ท้องฟ้า! มีนกเหล็กส่งเสียงคำรามบินออกมาจากประตู!"},
			{"who": "advisor", "focus": "field", "text": "อัศวิน นักปรุงยา และโกเลมตีศัตรูบนฟ้าไม่ได้ ต้องใช้นักธนู จอมเวทย์ นักบุญ หรือมังกร"},
			{"who": "king", "focus": "castle", "action": "gold", "text": "ทหารทั้งหลาย จงยืนหยัด! คลังหลวงจะสนับสนุนพวกเจ้าเต็มที่"},
		],
		"line": "นกเหล็กมาแล้ว! ยิงมันให้ร่วงก่อนถึงเมือง!",
		"groups": [
			{"enemy": "helicopter", "count": 4, "interval": 3.5, "delay": 2.0},
			{"enemy": "soldier", "count": 12, "interval": 0.9, "delay": 0.0},
			{"enemy": "humvee", "count": 3, "interval": 2.0, "delay": 12.0},
		],
	},
	{
		"title": "PHASE 5",
		"subtitle": "กองกำลังผสม — เหยี่ยวเหล็กสายฟ้าและป้อมเหล็ก",
		"interlude": [
			{"who": "narrator", "focus": "field", "text": "เปลวไฟเริ่มลุกลามไปทั่วชานเมือง... ควันดำปกคลุมท้องฟ้า"},
			{"who": "king", "focus": "castle", "action": "gold", "text": "นี่มันสงครามชัดๆ... เปิดคลังสมบัติหลวง! ใช้ทุกอย่างที่มีเพื่อปกป้องประชาชน"},
			{"who": "advisor", "focus": "gate", "text": "ประตูมิติขยายใหญ่ขึ้นทุกที... การบุกครั้งนี้จะหนักกว่าเดิมมาก มีเหยี่ยวเหล็กที่พุ่งชนเมืองได้ในพริบตา!"},
		],
		"line": "เหยี่ยวเหล็กพุ่งเร็วมาก ยิงสกัดตั้งแต่กลางทาง!",
		"groups": [
			{"enemy": "tank", "count": 3, "interval": 6.0, "delay": 0.0},
			{"enemy": "humvee", "count": 5, "interval": 1.6, "delay": 3.0},
			{"enemy": "jet", "count": 5, "interval": 1.8, "delay": 9.0},
			{"enemy": "helicopter", "count": 2, "interval": 3.0, "delay": 16.0},
		],
	},
	{
		"title": "BOSS PHASE",
		"subtitle": "การต่อสู้ครั้งสุดท้ายของเอลวาเรน",
		"boss": true,
		"interlude": [
			{"who": "scout", "focus": "gate", "text": "ท่านแม่ทัพ! เงาขนาดมหึมากำลังเคลื่อนไหวอยู่หลังประตู... มันใหญ่กว่าปราสาทเสียอีก!"},
			{"who": "king", "focus": "castle", "action": "gold", "text": "รวบรวมกำลังทั้งหมด! นี่คือการต่อสู้ครั้งสุดท้าย เพื่อเอลวาเรน!"},
		],
		"line": "ปกป้องเมืองหลวงไว้! เพื่ออาณาจักร!",
		"groups": [
			{"enemy": "soldier", "count": 14, "interval": 0.8, "delay": 0.0},
			{"enemy": "tank", "count": 3, "interval": 5.0, "delay": 4.0},
			{"enemy": "helicopter", "count": 3, "interval": 3.0, "delay": 8.0},
			{"enemy": "jet", "count": 4, "interval": 1.6, "delay": 14.0},
			{"enemy": "bomber", "count": 1, "interval": 1.0, "delay": 20.0},
			{"enemy": "soldier", "count": 16, "interval": 1.2, "delay": 30.0},
			{"enemy": "humvee", "count": 6, "interval": 2.5, "delay": 40.0},
		],
	},
]
