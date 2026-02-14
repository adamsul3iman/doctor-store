import 'package:doctor_store/features/product/domain/models/product_model.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// خدمة البحث الذكي مع تصحيح الأخطاء والمرادفات
class SmartSearchService {
  static final SmartSearchService instance = SmartSearchService._();
  SmartSearchService._();

  final _supabase = Supabase.instance.client;

  /// قاموس المرادفات الشامل الموسع - يشمل جميع المنتجات المحتملة واللهجات والأخطاء الشائعة
  static const Map<String, List<String>> _synonyms = {
    // ========== الفرشات والمراتب - شامل ==========
    'فرشة': ['فراش', 'مرتبة', 'مرتبه', 'فرشه', 'فراشة', 'سرير', 'تخت', 'bed', 'mattress', 'foam mattress', 'spring mattress', 'latex mattress', 'مرتبة طبية', 'مرتبة اسفنج', 'مرتبة سبرينج', 'مرتبة فندقية', 'مرتبة اطفال', 'مرتبة نفر', 'مرتبة نفرين', 'مرتبة كينج', 'مرتبة كوين', 'مرتبة مفرد', 'مرتبة مزدوج', 'مرتبة طبية', 'مرتبة طبية اسفنج', 'مرتبة طبية فوم'],
    'فراش': ['فرشة', 'مرتبة', 'فرشات', 'مراتب', 'سرير', 'تخت', 'bedding'],
    'مرتبة': ['فرشة', 'فراش', 'مرتبه', 'مراتب', 'سرير', 'تخت', 'bed', 'mattress'],
    'مراتب': ['فرشات', 'فراش', 'مرتبة'],
    'سرير': ['تخت', 'فرشة', 'مرتبة', 'bed', 'سراير'],
    'سراير': ['سرير', 'تخت', 'مراتب'],
    'تخت': ['سرير', 'فرشة', 'مرتبة', 'bed', 'bedroom furniture'],
    'تخت نفر': ['سرير مفرد', 'مرتبة نفر', 'single bed'],
    'تخت نفرين': ['سرير مزدوج', 'مرتبة نفرين', 'double bed'],
    'مرتبة نفر': ['فرشة نفر', 'مرتبة مفرد', 'single mattress', 'مرتبة 90', 'مرتبة 100'],
    'مرتبة نفرين': ['فرشة نفرين', 'مرتبة مزدوجة', 'double mattress', 'مرتبة 120', 'مرتبة 140'],
    'مرتبة كينج': ['فرشة كينج', 'king mattress', 'مرتبة 180', 'مرتبة 200'],
    'مرتبة كوين': ['فرشة كوين', 'queen mattress', 'مرتبة 160'],
    'مرتبة اطفال': ['فرشة طفل', 'مرتبة بيبي', 'kids mattress', 'children bed'],
    'مرتبة طبية': ['فرشة طبية', 'مرتبة صحية', 'orthopedic mattress', 'medical mattress', 'spine support'],
    'مرتبة اسفنج': ['فرشة اسفنج', 'مرتبة فوم', 'foam mattress', 'memory foam'],
    'مرتبة سبرينج': ['فرشة سبرينج', 'مرتبة زنبرك', 'spring mattress', 'innerspring'],
    'مرتبة لاتكس': ['فرشة لاتكس', 'natural latex mattress', 'organic mattress'],
    
    // ========== المخدات والوسائد - شامل ==========
    'مخدة': ['وسادة', 'وساده', 'مخده', 'وسايد', 'مخدات', 'pillow', 'cushion', 'مخدة طبية', 'مخدة اسفنج', 'مخدة فندقية', 'مخدة ريش', 'مخدة قطن', 'مخدة مخمل', 'مخدة حرير', 'وسادة اطفال', 'مخدة بيبي', 'مخدة رضيع'],
    'وسادة': ['مخدة', 'وساده', 'مخده', 'مخدات', 'pillow', 'cushion'],
    'مخدات': ['وسائد', 'مخده', 'وسايد', 'pillows', 'cushions'],
    'وسائد': ['مخدات', 'وسايد', 'pillows'],
    'مخدة طبية': ['وسادة طبية', 'مخدة اسفنج طبي', 'مخدة ذاكرة', 'memory foam pillow', 'memory pillow', 'مخدة للرقبة', 'مخدة cervica', 'مخدة صحية', 'مخدة spine', 'مخدة neck support'],
    'مخدة اسفنج': ['مخدة فوم', 'مخدة ذاكرة', 'foam pillow', 'sponge pillow'],
    'مخدة ريش': ['وسادة ريش', 'down pillow', 'feather pillow', 'مخدة اوز', 'مخدة بط'],
    'مخدة قطن': ['وسادة قطن', 'cotton pillow', 'مخدة قطنية'],
    'مخدة مخمل': ['وسادة مخمل', 'velvet pillow', 'velvet cushion'],
    'مخدة حرير': ['وسادة حرير', 'silk pillow'],
    'مخدة اطفال': ['مخدة بيبي', 'مخدة طفل', 'kids pillow', 'baby pillow'],
    'مخدة فندقية': ['مخدة خمس نجوم', 'مخدة فندق', 'hotel pillow', 'luxury pillow'],
    
    // ========== السجاد والموكيت - شامل ==========
    'سجادة': ['سجاده', 'زولية', 'زوليه', 'موكيت', 'سجاد', 'carpet', 'rug', 'سجاد تركي', 'سجاد ايراني', 'سجاد مودرن', 'سجاد كلاسيك', 'سجاد حرير', 'سجاد صوف', 'سجاد اطفال', 'سجادة مطبخ', 'سجادة حمام', 'سجادة صلاة', 'سجادة مدخل', 'doormat', 'runner'],
    'سجاد': ['سجادة', 'زولية', 'موكيت', 'سجادات', 'carpets', 'rugs', 'carpeting'],
    'زولية': ['سجادة', 'سجاد', 'موكيت', 'زوليه', 'زوليات', 'rug'],
    'زوليه': ['زولية', 'سجادة', 'سجاد'],
    'موكيت': ['سجادة', 'سجاد', 'زولية', 'carpet', 'wall to wall carpet', 'moquette'],
    'سجاد تركي': ['سجادة تركية', 'turkish carpet', 'turkish rug'],
    'سجاد ايراني': ['سجادة ايرانية', 'persian carpet', 'persian rug', 'سجاد فارسي'],
    'سجاد مودرن': ['سجاد عصري', 'سجاد حديث', 'modern carpet', 'contemporary rug'],
    'سجاد كلاسيك': ['سجاد تقليدي', 'سجاد كلاسيكي', 'classic carpet', 'traditional rug'],
    'سجاد حرير': ['سجادة حرير', 'silk carpet', 'silk rug'],
    'سجاد صوف': ['سجادة صوف', 'wool carpet', 'wool rug'],
    'سجاد اطفال': ['سجاد بيبي', 'سجاد غرفة اطفال', 'kids carpet', 'children rug'],
    'سجادة مطبخ': ['سجاد مطبخ', 'kitchen rug', 'kitchen mat'],
    'سجادة حمام': ['سجاد حمام', 'bath mat', 'bathroom rug'],
    'سجادة صلاة': ['سجاد صلاة', 'prayer rug', 'prayer mat', 'janamaz'],
    
    // ========== الستائر والبرادي - شامل ومتكامل ==========
    'ستارة': ['برداية', 'ستاره', 'ستائر', 'برادي', 'بردية', 'برداي', 'زيبرا', 'ستاير', 'ستائر زيبرا', 'ستارة زيبرا', 'برادي زيبرا', 'برداية زيبرا', 'ستائر رول', 'ستارة رول', 'ستائر blackout', 'ستارة blackout', 'ستائر معتمة', 'ستارة معتمة', 'ستائر عتمة', 'ستارة عتمة', 'ستائر شيفون', 'ستارة شيفون', 'ستائر سادة', 'ستارة سادة', 'ستائر مطبعة', 'ستارة مطبعة', 'ستائر دانتيل', 'ستارة دانتيل', 'ستائر مخمل', 'ستارة مخمل', 'ستائر حرير', 'ستارة حرير', 'curtain', 'curtains', 'drape', 'drapes', 'window covering'],
    'ستاره': ['ستارة', 'ستائر', 'برداية', 'بردية', 'برداي'],
    'برداية': ['ستارة', 'برداي', 'ستائر', 'ستاره', 'بردية', 'curtain', 'curtains', 'drapes', 'window curtain'],
    'برداي': ['برداية', 'ستارة', 'ستائر', 'ستاره', 'بردية', 'curtain', 'curtains'],
    'بردية': ['برداية', 'برداي', 'ستارة', 'ستائر'],
    'ستائر': ['برداية', 'ستارة', 'برادي', 'بردايات', 'curtains', 'drapes', 'window treatments'],
    'برادي': ['ستائر', 'برداية', 'ستارة', 'curtains', 'drapes', 'window coverings'],
    'ستائر زيبرا': ['ستارة زيبرا', 'زيبرا', 'zebra blinds', 'zebra curtains', 'day night blinds', 'ستائر حرارية', 'ستائر نهارية ليلية'],
    'زيبرا': ['ستائر زيبرا', 'ستارة زيبرا', 'zebra blinds', 'day night curtains'],
    'ستائر blackout': ['ستائر عتمة', 'ستائر معتمة', 'برادي عتمة', 'ستارة blackout', 'blackout curtains', 'room darkening curtains', 'ستائر حجب الضوء'],
    'ستائر شيفون': ['ستارة شيفون', 'شيفون', 'chiffon curtains', 'sheer curtains', 'ستائر شفافة', 'ستائر ناعمة'],
    'شيفون': ['ستائر شيفون', 'ستارة شيفون', 'chiffon', 'sheer fabric'],
    'ستائر رول': ['ستارة رول', 'رول', 'roller blinds', 'roll curtains', 'ستائر لوفة'],
    'ستائر سادة': ['ستارة سادة', 'سادة', 'plain curtains', 'solid curtains'],
    'ستائر مطبعة': ['ستارة مطبعة', 'مطبعة', 'patterned curtains', 'printed curtains'],
    'ستائر دانتيل': ['ستارة دانتيل', 'دانتيل', 'lace curtains', 'lace drapes'],
    'دانتيل': ['ستائر دانتيل', 'دانتيل قماش', 'lace', 'lace fabric'],
    'ستائر مخمل': ['ستارة مخمل', 'مخمل', 'velvet curtains', 'velvet drapes'],
    'مخمل': ['ستائر مخمل', 'قماش مخمل', 'velvet', 'velvet fabric'],
    'ستائر حرير': ['ستارة حرير', 'حرير', 'silk curtains', 'silk drapes'],
    'ستارة فندقية': ['ستائر فندق', 'ستارة خمس نجوم', 'hotel curtains', 'luxury curtains'],
    'ستائر اطفال': ['ستارة طفل', 'ستائر بيبي', 'ستارة غرفة اطفال', 'kids curtains', 'children drapes', 'nursery curtains'],
    'ستائر مطبخ': ['ستارة مطبخ', 'kitchen curtains', 'kitchen drapes'],
    'ستائر حمام': ['ستارة حمام', 'bathroom curtains', 'shower curtain'],
    
    // ========== الطاولات - شامل ==========
    'طاولة': ['طاوله', 'ترابيزة', 'ترابيزه', 'منضدة', 'طاولات', 'table', 'desk', 'طاولة جانبية', 'طاولة وسط', 'طاولة زاوية', 'طاولة تلفزيون', 'طاولة قهوة', 'coffee table', 'side table', 'end table', 'corner table', 'console table', 'dining table', 'study table', 'office table'],
    'طاوله': ['طاولة', 'ترابيزة', 'منضدة'],
    'طاولات': ['طاولة', 'ترابيز', 'منضدات', 'tables', 'desks'],
    'ترابيزة': ['طاولة', 'منضدة', 'ترابيزه', 'table'],
    'ترابيزه': ['ترابيزة', 'طاولة', 'منضدة'],
    'ترابيز': ['طاولات', 'منضدات', 'tables'],
    'منضدة': ['طاولة', 'ترابيزة', 'desk', 'منضده', ' bureau'],
    'منضده': ['منضدة', 'طاولة', 'ترابيزة'],
    'طاولة جانبية': ['ترابيزة جانبية', 'side table', 'end table', 'طاولة كنب', 'طاولة بجانب الكنب'],
    'طاولة وسط': ['ترابيزة وسط', 'coffee table', 'center table', 'طاولة صالون', 'طاولة living'],
    'طاولة زاوية': ['ترابيزة زاوية', 'corner table', 'زاوية', 'corner desk'],
    'طاولة تلفزيون': ['ترابيزة تلفزيون', 'tv table', 'tv stand', 'تلفزيون', 'TV unit', 'media console'],
    'طاولة قهوة': ['ترابيزة قهوة', 'coffee table', 'طاولة وسط', 'center table'],
    'طاولة طعام': ['ترابيزة طعام', 'dining table', 'طاولة سفرة', 'table kitchen'],
    'طاولة مطبخ': ['ترابيزة مطبخ', 'kitchen table', 'dining kitchen'],
    'طاولة مكتب': ['ترابيزة مكتب', 'office desk', 'desk', 'طاولة study', 'طاولة كمبيوتر'],
    
    // ========== المفارش والأغطية - شامل ==========
    'مفرش': ['مفارش', 'غطاء', 'غطا', 'لحاف', 'مفروشات', 'cover', 'bedsheet', 'bed sheet', 'bed cover', 'spread', 'bedspread', 'مفرش سرير', 'مفرش نفر', 'مفرش نفرين', 'مفرش كينج', 'مفرش كوين', 'مفرش اطفال', 'مفرش قطن', 'مفرش حرير', 'مفرش مخمل'],
    'مفارش': ['مفرش', 'غطاء', 'لحاف', 'covers', 'bedsheets', 'bed sheets', 'bedding'],
    'مفروشات': ['مفارش', 'مفروشات منزل', 'مفروشات غرف نوم', 'furnishings', 'home furnishings', 'textiles'],
    'لحاف': ['غطاء', 'مفرش', 'بطانية', 'لحافات', 'blanket', 'comforter', 'duvet', 'quilt', 'لحاف صيفي', 'لحاف شتوي', 'لحاف قطن', 'لحاف اسفنج', 'لحاف ريش'],
    'بطانية': ['لحاف', 'مفرش', 'blanket', 'throw', 'بطانية صوف', 'بطانية فرو', 'بطانية اطفال', 'بطانية بيبي'],
    'غطاء': ['مفرش', 'لحاف', 'غطا', 'cover', 'غطاء سرير', 'غطاء كنب', 'غطاء صوفا', 'غطاء تخت', 'غطاء مخدة', 'غطاء وسادة'],
    'غطا': ['غطاء', 'مفرش', 'لحاف'],
    'مفرش سرير': ['مفرش تخت', 'مفرش bed', 'bedspread', 'bed cover'],
    'مفرش نفر': ['مفرش مفرد', 'single bedsheet', 'single bed cover', 'مفرش 90', 'مفرش 100'],
    'مفرش نفرين': ['مفرش مزدوج', 'double bedsheet', 'double bed cover', 'مفرش 120', 'مفرش 140'],
    'مفرش كينج': ['king bedsheet', 'king bed cover', 'مفرش كبير', 'مفرش 180', 'مفرش 200'],
    'مفرش كوين': ['queen bedsheet', 'queen bed cover', 'مفرش 160'],
    'مفرش اطفال': ['مفرش بيبي', 'مفرش طفل', 'kids bedsheet', 'children bed cover', 'مفرش crib', 'مفرش سرير اطفال'],
    'مفرش قطن': ['قطني', 'cotton bedsheet', 'natural cotton cover'],
    'مفرش حرير': ['silk bedsheet', 'satin bedsheet', 'silk cover'],
    'مفرش مخمل': ['velvet bedsheet', 'velvet bed cover', 'مخمل'],
    
    // ========== الديكور والاكسسوارات - شامل ==========
    'ديكور': ['زينة', 'تزيين', 'اكسسوار', 'ديكورات', 'اكسسوارات', 'decor', 'decoration', 'home decor', 'interior decor', 'accessories', 'ornaments', ' ديكور بيت', 'ديكور منزل', 'ديكور غرف', 'ديكورات جدارية', 'ديكور ارضي', 'ديكور طاولات', 'ديكور رفوف'],
    'زينة': ['ديكور', 'تزيين', 'اكسسوار', 'decoration', 'ornaments', 'decorations', 'festive decor'],
    'تزيين': ['ديكور', 'زينة', 'decorating', 'embellishment'],
    'اكسسوار': ['ديكور', 'زينة', 'اكسسوارات', 'accessory', 'accessories', 'decor piece', 'ديكور صغير', 'قطعة ديكور'],
    'اكسسوارات': ['اكسسوار', 'ديكورات', 'accessories', 'decor items'],
    'ديكورات': ['ديكور', 'زينة', 'اكسسوارات', 'decorations', 'decor items'],
    'ديكور جداري': ['زينة جدارية', 'اكسسوار جداري', 'wall decor', 'wall art', 'wall hanging', 'لوحة جدارية', 'ساعة حائط', 'مرآة حائط', 'جدارية'],
    'ديكور ارضي': ['زينة ارضية', 'اكسسوار ارضي', 'floor decor', 'vase', 'مزهرية', 'تحفة', 'تمثال', 'ستاند', 'ستاند ديكور'],
    'ديكور طاولات': ['زينة طاولات', 'اكسسوار طاولات', 'table decor', 'table centerpiece', 'حامل شموع', 'شمعدان', 'صينية ديكور', 'tray decor'],
    'مزهرية': ['فازة', 'فازه', ' vase', 'flower vase', 'jar', 'زجاجة زهور', 'حامل ورد'],
    'فازة': ['مزهرية', 'فازه', 'vase'],
    'فازه': ['فازة', 'مزهرية'],
    'تمثال': ['تحفة', 'ديكور', 'statue', 'sculpture', 'figurine', 'تحفة فنية', 'قطعة فنية'],
    'تحفة': ['تمثال', 'ديكور', 'artifact', 'antique', 'piece', 'antique piece'],
    'ساعة حائط': ['ساعة جدارية', 'wall clock', 'ساعة ديكور', 'ساعة زينة'],
    'مرآة': ['مراية', 'مراه', 'mirror', 'مرآة ديكور', 'مرآة جدارية', 'مرآة حائط', 'wall mirror'],
    'مراية': ['مرآة', 'مراه', 'mirror'],
    'شمعدان': ['حامل شموع', 'candle holder', 'شمعة', 'candle'],
    'حامل شموع': ['شمعدان', 'candle holder'],
    'صينية': ['صينيه', ' Tray', 'serving tray', 'صينية ديكور', 'صينية تقديم', 'صينية فضة', 'صينية خشب'],
    'صينيه': ['صينية', 'tray'],
    
    // ========== الأطفال والبيبي - شامل ==========
    'طفل': ['أطفال', 'بيبي', 'رضيع', 'اولاد', 'بيبيه', 'child', 'baby', 'infant', 'kid', 'toddler', 'صغير', 'ولد', 'بنت', 'ذكر', 'انثى', 'طفل صغير', 'طفل رضيع'],
    'أطفال': ['طفل', 'بيبي', 'رضيع', 'اطفال', 'اولاد', 'children', 'kids', 'babies', 'infants', 'youth', 'minors', 'صغار'],
    'اطفال': ['أطفال', 'طفل', 'بيبي'],
    'بيبي': ['طفل', 'أطفال', 'رضيع', 'بيبيه', 'baby', 'infant', 'newborn', 'neonate', 'recien nacido'],
    'بيبيه': ['بيبي', 'طفل', 'baby'],
    'رضيع': ['طفل', 'بيبي', 'أطفال', 'infant', 'newborn', 'neonate', 'baby', 'recien nacido', 'طفل حديث الولادة'],
    'اولاد': ['أطفال', 'طفل', 'boys', 'kids', 'children', 'صبيان', 'ولاد', 'ولد'],
    'ولاد': ['اولاد', 'أطفال', 'boys'],
    'بنات': ['بنت', 'girls', 'female children', 'طفلة'],
    'طفل صغير': ['بيبي', 'toddler', 'little child', 'small kid'],
    'أثاث اطفال': ['اثاث بيبي', 'furniture kids', 'children furniture', 'baby furniture', 'kids room furniture', 'غرفة اطفال', 'kids bedroom'],
    'غرفة اطفال': ['غرفة بيبي', 'kids bedroom', 'children room', 'nursery', 'nursery room'],
    'سرير اطفال': ['سرير بيبي', 'crib', 'cot', 'children bed', 'baby bed', 'infant bed', 'سرير رضيع'],
    
    // ========== الأثاث والمفروشات - شامل ==========
    'صوفا': ['كنب', 'اريكة', 'sofa', 'couch'],
    'اريكة': ['كنب', 'صوفا', 'اريكه', 'settee'],
    'اريكه': ['اريكة', 'كنب', 'صوفا'],
    'كنبات': ['كنب', 'sofas', 'couches'],
    'كنب مودرن': ['صوفا مودرن', 'modern sofa', 'contemporary couch', 'كنب عصري'],
    'كنب كلاسيك': ['صوفا كلاسيك', 'classic sofa', 'traditional couch', 'كنب تقليدي'],
    'كنب ركنة': ['ركنة', 'كنب زاوية', 'corner sofa', 'sectional sofa', 'L shaped sofa', 'كنب حرف L'],
    'ركنة': ['كنب ركنة', 'زاوية', 'corner sofa', 'sectional'],
    'كنب استرخاء': ['كنب recliner', 'reclining sofa', 'recliner chair', 'relax sofa', 'كنب مريح'],
    'كنب سرير': ['sofa bed', 'convertible sofa', 'sleeper sofa', 'كنب يفتح سرير', 'كنب سرير نفر'],
    'جلسة': ['مجلس', 'جلسات', 'lounge', 'sitting area', 'seating', 'جلسة ارضية', 'جلسة عربية', 'jalsa', 'majlis'],
    'مجلس': ['جلسة', 'مجالس', 'lounge', 'majlis', 'sitting room', 'reception room', 'diwan'],
    'جلسة ارضية': ['جلسة عربية', 'jalsa', 'floor seating', 'ground seating', 'majlis arabi'],
    'جلسة عربية': ['جلسة ارضية', 'majlis', 'traditional seating', 'arabic majlis'],
    'خزانة': ['دولاب', 'خزانه', 'خزائن', 'closet', 'wardrobe', 'cupboard', 'cabinet', 'almirah', 'خزانة ملابس', 'خزانة كتب', 'خزانة احذية'],
    'دولاب': ['خزانة', 'دواليب', 'wardrobe', 'closet', 'cabinet', 'cupboard', 'almirah', 'armoire'],
    'خزانه': ['خزانة', 'دولاب'],
    'دواليب': ['دولاب', 'خزائن', 'wardrobes', 'closets'],
    'خزائن': ['خزانة', 'دواليب', 'cabinets', 'cupboards'],
    'خزانة ملابس': ['دولاب ملابس', 'wardrobe', 'clothing cabinet', 'closet', 'almirah'],
    'خزانة كتب': ['دولاب كتب', 'bookcase', 'bookshelf', 'library cabinet', 'd bookshelf'],
    'رفوف': ['رف', 'رفوف كتب', 'رفوف ديكور', 'shelves', 'shelving', 'book shelves', 'wall shelves'],
    'رف': ['رفوف', 'shelf', 'rack'],
    
    // ========== الفنادق والجودة الفاخرة - شامل ==========
    'فندق': ['فنادق', 'فندقي', 'هوتيل', 'hotel', 'luxury', 'motel', 'resort', 'inn', 'lodge', 'hostel'],
    'فنادق': ['فندق', 'فندقية', 'hotels', 'resorts', 'luxury hotels'],
    'فندقي': ['فندق', 'فاخر', 'luxury', 'hotel quality', 'premium', 'five star', '5 star'],
    'خمس نجوم': ['فاخر', 'فندقي', 'VIP', '5 stars', 'luxury', 'premium', 'top quality', 'first class', 'ممتاز', 'عالي الجودة'],
    'فاخر': ['خمس نجوم', 'فندقي', 'VIP', 'luxury', 'premium', 'deluxe', 'grand', 'elegant', 'sophisticated', 'high-end', 'high quality', 'غالي', 'راقي', 'مميز'],
    'VIP': ['فاخر', 'فندقي', 'خمس نجوم', 'مميز', 'exclusive', 'private', 'premium'],
    'فندقية': ['فندق', 'فنادق', 'hotel style', 'فاخر', 'luxury'],
    'جودة عالية': ['high quality', 'فاخر', 'premium', 'superior', 'excellent', 'mumtaz', 'ممتاز'],
    'جودة ممتازة': ['excellent quality', 'فاخر', 'premium', 'superior', 'ممتاز', 'عالي الجودة'],
    
    // ========== الأحجام والمقاسات - شامل ==========
    'كبير': ['large', 'كبيرة', 'كبيره', 'كبار', 'huge', 'big', 'enormous', 'massive', 'tall', 'wide', 'عريض', 'طويل', 'ضخم', 'واسع'],
    'كبيرة': ['كبير', 'large', 'huge', 'big'],
    'صغير': ['small', 'صغيرة', 'صغيره', 'صغار', 'tiny', 'little', 'petite', 'compact', 'mini', 'narrow', 'صغير الحجم', 'ضيق'],
    'صغيرة': ['صغير', 'small', 'tiny', 'little'],
    'وسط': ['medium', 'متوسط', 'وسطي', 'average', 'moderate', 'regular', 'standard', 'normal', 'mid size', 'middle'],
    'متوسط': ['وسط', 'medium', 'average', 'moderate'],
    'مقاس': ['مقاسات', 'حجم', 'حجام', 'size', 'dimension', 'measurement', 'scale', 'gauge'],
    'مقاسات': ['مقاس', 'sizes', 'dimensions', 'measurements', 'حجام', 'احجام'],
    'حجم': ['مقاس', 'احجام', 'size', 'volume', 'capacity', 'bulk', 'mass'],
    'احجام': ['حجم', 'sizes', 'مقاسات', 'dimensions'],
    'مقاس صغير': ['حجم صغير', 'small size', 'size small', 's', 'sm'],
    'مقاس كبير': ['حجم كبير', 'large size', 'size large', 'l', 'lg', 'xl', 'xxl'],
    'مقاس وسط': ['حجم وسط', 'medium size', 'size medium', 'm', 'md'],
    'مقاس مخصص': ['مقاس خاص', 'custom size', 'tailored size', 'made to measure', 'hajem makhassas'],
    
    // ========== الألوان - شامل ومتكامل ==========
    'أبيض': ['white', 'بيضا', 'ابيض', 'بيج', 'كريمي', 'كريم', 'ابيض ثلجي', 'white pearl', 'ابيض ناصع', 'bright white', 'off white'],
    'ابيض': ['أبيض', 'white', 'بيضا'],
    'بيضا': ['أبيض', 'ابيض', 'white'],
    'أسود': ['black', 'سواد', 'اسود', 'اسود فحمي', 'black charcoal', 'deep black', 'اسود ناصع', 'matte black', 'glossy black'],
    'اسود': ['أسود', 'black', 'سواد'],
    'سواد': ['اسود', 'أسود'],
    'أحمر': ['red', 'احمر', 'حمرا', 'أحمر غامق', 'احمر فاتح', 'احمر ناري', 'red wine', 'burgundy', 'maroon', 'cherry red', 'crimson', 'scarlet'],
    'احمر': ['أحمر', 'red', 'حمرا'],
    'حمرا': ['أحمر', 'احمر', 'red'],
    'أزرق': ['blue', 'ازرق', 'زرقا', 'نيلي', 'ازرق فاتح', 'ازرق غامق', 'ازرق سماوي', 'sky blue', 'navy blue', 'royal blue', 'turquoise', 'teal', 'cyan', 'blue azure'],
    'ازرق': ['أزرق', 'blue', 'زرقا', 'نيلي'],
    'زرقا': ['أزرق', 'ازرق', 'blue'],
    'نيلي': ['ازرق', 'أزرق', 'navy', 'dark blue'],
    'أخضر': ['green', 'اخضر', 'خضرا', 'اخضر فاتح', 'اخضر غامق', 'اخضر زيتي', 'olive green', 'lime green', 'mint green', 'forest green', 'emerald green', 'green sage'],
    'اخضر': ['أخضر', 'green', 'خضرا'],
    'خضرا': ['أخضر', 'اخضر', 'green'],
    'أصفر': ['yellow', 'اصفر', 'صفرا', 'اصفر ذهبي', 'gold yellow', 'lemon yellow', 'mustard yellow', 'pale yellow'],
    'اصفر': ['أصفر', 'yellow', 'صفرا'],
    'صفرا': ['أصفر', 'اصفر', 'yellow'],
    'برتقالي': ['orange', 'orange color', 'orange hue', 'naranji'],
    'بنفسجي': ['purple', 'violet', 'lilac', 'lavender', 'mauve'],
    'وردي': ['pink', 'زهري', 'rose', 'fuchsia', 'hot pink', 'pastel pink', 'baby pink', 'light pink'],
    'زهري': ['وردي', 'pink', 'rose'],
    'بني': ['brown', 'coffee', 'chocolate', 'cocoa', 'tan', 'camel', 'beige brown', 'dark brown', 'light brown'],
    'بيج': ['beige', 'كريمي', 'كريم', 'أبيض', 'باج', 'off white', 'ivory', 'cream', 'sand', 'taupe', 'natural', 'ecru'],
    'كريمي': ['بيج', 'كريم', 'cream', 'ivory', 'off white'],
    'كريم': ['كريمي', 'بيج', 'cream'],
    'رمادي': ['grey', 'gray', 'silver', 'رمادي فاتح', 'رمادي غامق', 'charcoal grey', 'slate grey', 'ash grey', 'silver grey', 'metal grey'],
    'فضي': ['silver', 'platinum', 'metallic', 'silver grey'],
    'ذهبي': ['gold', 'golden', 'yellow gold', 'rose gold', 'gold metallic'],
    'تركواز': ['turquoise', 'turquoise blue', 'cyan', 'aqua'],
    'عنابي': ['maroon', 'burgundy', 'wine red', 'dark red'],
    
    // ========== الخصومات والعروض - شامل ==========
    'عرض': ['عروض', 'تخفيض', 'خصم', 'sale', 'offer', 'deal', 'promotion', 'bargain', 'عرض خاص', 'عرض محدود', 'عرض لفترة محدودة', 'limited offer', 'special offer', 'hot deal'],
    'عروض': ['عرض', 'تخفيضات', 'خصومات', 'sales', 'offers', 'deals', 'promotions', 'hot deals', 'flash sale', 'seasonal sale', 'mega sale', 'big sale'],
    'تخفيض': ['عرض', 'خصم', 'sale', 'discount', 'price cut', 'markdown', 'reduction', 'تخفيض سعر', 'تخفيض كبير', 'big discount', 'huge discount'],
    'تخفيضات': ['تخفيض', 'عروض', 'خصومات', 'discounts', 'sales', 'price cuts'],
    'خصم': ['تخفيض', 'عرض', 'discount', 'sale', 'reduction', 'deduction', 'savings', 'خصم مباشر', 'خصم نسبة', 'percentage off', 'خصم كبير'],
    'خصومات': ['خصم', 'تخفيضات', 'عروض', 'discounts', 'sale offers'],
    'رخيص': ['سعر منخفض', 'اقتصادي', 'cheap', 'affordable', 'low price', 'budget friendly', 'economic', ' inexpensive', ' bargain', 'value for money', 'سعر رخيص'],
    'سعر منخفض': ['رخيص', 'affordable price', 'low cost', 'budget price', 'economic price'],
    'اقتصادي': ['رخيص', 'economic', 'budget', 'affordable', 'cost effective', 'value'],
    'sale': ['تخفيض', 'خصم', 'عرض', 'sale', 'on sale', 'big sale', 'final sale'],
    'discount': ['خصم', 'تخفيض', 'price off', 'markdown', 'reduction'],
    'hot deal': ['عرض ساخن', 'صفقة ساخنة', 'best seller', 'top deal'],
    'flash sale': ['تخفيض فلاش', 'بيع سريع', 'عرض مؤقت', 'flash offer'],
    'clearance': ['تصفية', 'بيع التصفية', 'final clearance', 'last chance'],
    'buy one get one': ['اشتري واحد واحصل على واحد مجاني', 'bogo', 'عرض الشراء', '1+1'],
    'bogo': ['buy one get one', '1+1', 'عروض الشراء'],
    'free shipping': ['شحن مجاني', 'توصيل مجاني', 'delivery free'],
    'شحن مجاني': ['free shipping', 'توصيل مجاني', 'delivery free', 'free delivery'],
    
    // ========== المواد والخامات - شامل ==========
    'قطن': ['cotton', 'قطني', 'natural', 'pure cotton', '100% cotton', 'organic cotton', 'egyptian cotton', 'american cotton', 'natural fiber', 'قبلan'],
    'قطني': ['قطن', 'cotton', 'made of cotton'],
    '100% قطن': ['pure cotton', 'natural cotton', 'organic cotton', '100% cotton'],
    'مصري': ['egyptian', 'egypt', 'مصر', 'made in egypt', 'egyptian cotton', 'egyptian quality'],
    'تركي': ['turkish', 'turkey', 'تركيا', 'made in turkey', 'turkish quality'],
    'حرير': ['silk', 'حريري', 'luxurious', 'pure silk', '100% silk', 'mulberry silk', 'natural silk', 'satin silk', 'chinese silk'],
    'حريري': ['حرير', 'silky', 'silk like', 'smooth'],
    'صوف': ['wool', 'صوفي', 'woolen', 'pure wool', 'merino wool', 'lamb wool', 'natural wool', 'wool fiber'],
    'صوفي': ['صوف', 'woolen', 'wool like', 'made of wool'],
    'ميموري فوم': ['memory foam', 'فوم', 'اسفنج', 'foam', 'visco elastic', 'memory pillow', 'memory mattress', 'smart foam'],
    'فوم': ['ميموري فوم', 'اسفنج', 'foam', 'sponge', 'polyurethane', 'cushion foam', '高密度海绵', '高密度海绵'],
    'اسفنج': ['فوم', 'ميموري فوم', 'sponge', 'foam rubber', 'poly foam'],
    'جلد': ['leather', 'جلد طبيعي', 'real leather', 'genuine leather', 'cow leather', 'animal leather', 'leather hide'],
    'leather': ['جلد', 'skin', 'hide', 'leather material'],
    'جلد صناعي': ['faux leather', 'vegan leather', 'synthetic leather', 'pleather', 'artificial leather', 'PU leather', 'pvc leather'],
    'شمواه': ['suede', 'suede leather', 'nubuck', 'velvet suede'],
    'كتان': ['linen', 'flax', 'linen fabric', 'natural linen'],
    'ستان': ['satin', 'sateen', 'silk satin', 'glossy fabric'],
    'ستانلس ستيل': ['stainless steel', 'steel', 'metal', 'inox', 'stainless'],
    'خشب': ['wood', 'wooden', 'timber', 'solid wood', 'natural wood', 'hardwood', 'softwood', 'mdf', 'plywood'],
    'خشبي': ['خشب', 'wooden', 'made of wood'],
    'زجاج': ['glass', 'crystal', 'glassware', 'mirror glass', 'tempered glass'],
    'معدن': ['metal', 'metallic', 'iron', 'steel', 'aluminum', 'copper', 'brass', 'metallic'],
    'بلاستيك': ['plastic', 'pvc', 'acrylic', 'polymer', 'synthetic', 'resin'],
    'اكريليك': ['acrylic', 'plexiglass', 'perspex', 'acrylic plastic'],
    'مطاط': ['rubber', 'latex', 'silicone', 'elastic'],
    
    // ========== الغرف والأماكن - شامل ==========
    'غرفة نوم': ['bedroom', 'غرف نوم', 'master bedroom', 'kids bedroom', 'children bedroom', 'guest bedroom', 'bed room', 'sleeping room', 'chambre', 'recámara', 'schlafzimmer'],
    'غرف نوم': ['غرفة نوم', 'bedrooms', 'master bedrooms'],
    'صالون': ['living room', 'majlis', 'reception', 'lounge', 'sitting room', 'drawing room', 'parlor', 'sala', 'salle de sejour'],
    'مطبخ': ['kitchen', 'مطابخ', 'cooking area', 'cuisine', 'cocina', 'kuche', 'kitchenette', 'culinary space'],
    'مطابخ': ['مطبخ', 'kitchens', 'kitchen areas'],
    'حمام': ['bathroom', 'toilet', 'restroom', 'washroom', 'wc', 'lavatory', 'حمامات', 'salle de bain', 'bano', 'bad'],
    'حمامات': ['حمام', 'bathrooms'],
    'غرفة معيشة': ['living room', 'lounge', 'family room', 'recreation room', 'living area'],
    'غرفة ضيوف': ['guest room', 'visitor room', 'spare room', 'guest bedroom'],
    'غرفة ملابس': ['dressing room', 'walk in closet', 'wardrobe room', 'changing room', 'vestiaire'],
    'مكتب': ['office', 'study', 'work room', 'workspace', 'desk area', 'home office', 'bureau'],
    'بلكونة': ['balcony', 'terrace', 'veranda', 'patio', 'deck', 'balcon'],
    'حديقة': ['garden', 'yard', 'backyard', 'lawn', 'park', 'outdoor', 'jardin', 'giardino'],
    
    // ========== أنواع الستائر الخاصة ==========
    'ستائر فينيسية': ['venetian blinds', 'horizontal blinds', 'wooden blinds', 'slat blinds', 'blinds'],
    'ستائر عمودية': ['vertical blinds', 'vertical shades', 'panel blinds'],
    'ستائر رومانية': ['roman shades', 'roman blinds', 'fabric shades', 'folding shades'],
    'ستائر بلاك اوت': ['blackout curtains', 'room darkening curtains', 'thermal curtains', 'opaque curtains'],
    
    // ========== أنواع الفرشات والمراتب الخاصة ==========
    'مرتبة اسبنجر': ['spring mattress', 'coil mattress', 'innerspring mattress', 'traditional mattress'],
    'مرتبة بوكت اسبنجر': ['pocket spring mattress', 'pocketed coil mattress', 'encased spring mattress', 'independent spring mattress'],
    'مرتبة visco': ['viscoelastic mattress', 'memory foam mattress', 'foam mattress', 'pressure relief mattress'],
    'مرتبة طبية اسفنج': ['medical foam mattress', 'therapeutic foam mattress', 'orthopedic foam'],
    'مرتبة طبية زنبرك': ['orthopedic spring mattress', 'medical spring mattress'],
    
    // ========== أنواع المخدات الخاصة ==========
    'مخدة visco': ['visco pillow', 'memory foam pillow', 'viscoelastic pillow'],
    'مخدة لاتكس': ['latex pillow', 'natural latex pillow', 'rubber pillow'],
    'مخدة ريش اوز': ['down pillow', 'goose down pillow', 'feather pillow', 'eiderdown pillow'],
    'مخدة مائي': ['water pillow', 'hydraulic pillow'],
    'مخدة تدليك': ['massage pillow', 'shiatsu pillow', 'vibration pillow'],
    'مخدة تبريد': ['cooling pillow', 'cool gel pillow', 'refrigerated pillow'],
    
    // ========== أنواع السجاد الخاصة ==========
    'سجاد اكريليك': ['acrylic carpet', 'acrylic rug', 'synthetic carpet'],
    'سجاد بوليستر': ['polyester carpet', 'polyester rug', 'synthetic rug'],
    'سجاد خارجي': ['outdoor carpet', 'garden rug', 'patio rug', 'indoor outdoor carpet'],
    
    // ========== أنواع الكنب الخاصة ==========
    'كنب جلد': ['leather sofa', 'leather couch', 'genuine leather sofa'],
    'كنب مخمل': ['velvet sofa', 'velvet couch', 'plush sofa'],
    'كنب قماش': ['fabric sofa', 'textile sofa', 'cloth sofa', 'upholstered sofa'],
    'كنب rlc': ['reclining sofa', 'recliner sofa', 'relax sofa'],
    'كنب زاوية': ['corner sofa', 'sectional sofa', 'L shaped sofa', 'modular sofa'],
    'كنب u': ['U shaped sofa', 'large sectional', 'wrap around sofa'],
    'كنب موديولار': ['modular sofa', 'sectional sofa', 'configurable sofa', 'flexible sofa'],
    
    // ========== مفردات التصميم والستايل ==========
    'عصري': ['مودرن', 'modern', 'contemporary', 'current', 'trendy'],
    'كلاسيك': ['classic', 'traditional', 'vintage', 'antique', 'old style', 'timeless', 'تقليدي'],
    'كاجوال': ['casual', 'informal', 'relaxed', 'comfortable', 'everyday'],
    'طبيعي': ['natural', 'organic', 'eco friendly', 'green', 'sustainable', 'biological'],
    'صناعي': ['industrial', 'factory style', 'loft', 'urban', 'raw'],
    'ريفي': ['rustic', 'country', 'farmhouse', 'cottage', 'rural', 'vintage country'],
    'بوهيمي': ['bohemian', 'boho', 'gypsy', 'eclectic', 'artistic', 'free spirit'],
    
    // ========== مفردات إضافية للتخصيص ==========
    'تخصيص': ['customize', 'custom', 'personalize', 'tailor made', 'bespoke', 'made to order', 'custom made'],
    'مخصص': ['customized', 'personalized', 'tailored', 'custom', 'bespoke'],
    'اوردر': ['order', 'custom order', 'special order', 'made to order'],
    'طلب خاص': ['special request', 'custom request', 'personal order'],
    
    // ========== مفردات الخدمة والتوصيل ==========
    'توصيل': ['delivery', 'shipping', 'shipment', 'transport', 'courier', 'توصيل مجاني', 'fast delivery', 'same day delivery'],
    'تركيب': ['installation', 'setup', 'assembling', 'fitting', 'mounting', 'assembly service'],
    'صيانة': ['maintenance', 'repair', 'servicing', 'care', 'warranty service'],
    'ضمان': ['warranty', 'guarantee', 'protection', 'assurance', 'warranty card'],
    'استبدال': ['exchange', 'replacement', 'swap', 'return policy'],
    'استرجاع': ['return', 'refund', 'money back', 'return policy'],
    
    // ========== مفردات الموسم والمناسبات ==========
    'رمضان': ['ramadan', 'ramazan', 'month of fasting', 'holy month'],
    'عيد': ['eid', 'festival', 'celebration', 'holiday', 'feast'],
    'كريسماس': ['christmas', 'xmas', 'noel', 'yuletide', 'holiday season'],
    'الشتاء': ['winter', 'cold season', 'christmas season'],
    'الصيف': ['summer', 'hot season', 'warm weather'],
    'موسم': ['season', 'period', 'time', 'collection'],
    
    // ========== مفردات الجودة والتقييم ==========
    'جودة': ['quality', 'caliber', 'standard', 'grade', 'excellence', 'high quality'],
    'ممتاز': ['excellent', 'outstanding', 'superb', 'first rate', 'top notch', 'premium', 'great', 'awesome'],
    'جيد': ['good', 'nice', 'decent', 'satisfactory', 'acceptable', 'fair'],
    'رديء': ['bad', 'poor', 'low quality', 'inferior', 'substandard'],
    'اصلي': ['original', 'authentic', 'genuine', 'real', 'true', 'natural'],
    'تقليد': ['imitation', 'fake', 'copy', 'replica', 'counterfeit', 'knock off'],
    
    // ========== مفردات الحساسية والصحة ==========
    'مضاد للحساسية': ['anti allergy', 'hypoallergenic', 'allergy free', 'non allergenic'],
    'طببي': ['medical', 'therapeutic', 'health', 'wellness', 'orthopedic'],
    'صحي': ['healthy', 'healthful', 'salutary', 'wholesome', 'hygienic'],
    'مريح': ['comfortable', 'cozy', 'snug', 'comfy', 'relaxing', 'pleasant'],
    'ناعم': ['soft', 'smooth', 'silky', 'gentle', 'tender', 'delicate'],
    'ثقيل': ['heavy', 'thick', 'dense', 'weighty', 'substantial'],
    'خفيف': ['light', 'lightweight', 'airy', 'thin', 'slim'],
    'دافئ': ['warm', 'cozy', 'heated', 'thermal', 'insulated'],
    'بارد': ['cool', 'cold', 'chilly', 'refreshing', 'cooling'],
    
    // ========== أرقام وقياسات شائعة ==========
    'سنتي': ['cm', 'centimeter', 'santim'],
    'متر': ['m', 'meter', 'metre'],
    'مليمتر': ['mm', 'millimeter'],
    'انش': ['inch', 'inches', '"'],
    'قدم': ['foot', 'feet', "'"],
    
    // ========== مفردات التعبئة والتغليف ==========
    'علبة': ['box', 'case', 'carton', 'package', 'container'],
    'كرتون': ['carton', 'cardboard box', 'box'],
    'شنطة': ['bag', 'sack', 'tote', 'carry bag'],
    'كيس': ['sack', 'bag', 'pouch'],
    'غلاف': ['cover', 'wrapper', 'envelope', 'sleeve'],
    'تغليف': ['packaging', 'wrapping', 'packing', 'protection'],
    
    // ========== أوامر البحث الشائعة ==========
    'جديد': ['new', 'fresh', 'latest', 'recent', 'brand new', 'new arrival', 'new stock'],
    'جديدة': ['جديد', 'new', 'fresh'],
    'واصل حديثا': ['newly arrived', 'fresh stock', 'just in', 'new collection'],
    'وصل حديثا': ['new arrival', 'new stock', 'fresh in'],
    'الأكثر مبيعا': ['best seller', 'top seller', 'popular', 'trending', 'hot item'],
    'الأكثر زيارة': ['most visited', 'most viewed', 'popular', 'trending'],
    'مقترح': ['recommended', 'suggested', 'proposed', 'advised'],
    'محبوب': ['loved', 'favorite', 'popular', 'liked', 'preferred'],
    
    // ========== أنواع الطاولات الخاصة ==========
    'تسريحة': ['dressing table', 'vanity table', 'makeup table', 'dresser', 'vanity'],
    'تلفزيون طاولة': ['tv table', 'tv stand', 'media console', 'entertainment unit'],
    'مدخل': ['entryway', 'foyer', 'entrance', 'hallway', 'lobby', 'mudroom'],
    'كونسول': ['console table', 'hall table', 'entry table', 'sofa table'],
    
    // ========== أنواع الإضاءة ==========
    'اباجورة': ['table lamp', 'bedside lamp', 'nightstand lamp', 'lamp'],
    'ثريا': ['chandelier', 'pendant light', 'ceiling light', 'hanging light'],
    'سبوت لايت': ['spotlight', 'spot light', 'downlight', 'ceiling spot'],
    'لمبة': ['bulb', 'light bulb', 'lamp', 'light'],
    'انارة': ['lighting', 'illumination', 'lights', 'light fixtures'],
    'اضاءة': ['lighting', 'illumination', 'light'],
    
    // ========== أنواع المرايا ==========
    'مرآة جدارية': ['wall mirror', 'hanging mirror', 'decorative mirror'],
    'مرآة ارضية': ['floor mirror', 'standing mirror', 'full length mirror', 'cheval mirror'],
    'مرآة تسريحة': ['vanity mirror', 'makeup mirror', 'dressing mirror'],
    'مرآة مكبرة': ['magnifying mirror', 'magnifier mirror', 'zoom mirror'],
    
    // ========== أنواع الفازات ==========
    'فازة زجاج': ['glass vase', 'crystal vase', 'transparent vase'],
    'فازة سيراميك': ['ceramic vase', 'pottery vase', 'clay vase'],
    'فازة معدن': ['metal vase', 'brass vase', 'copper vase', 'gold vase'],
    'فازة خشب': ['wooden vase', 'wood vase', 'bamboo vase'],
    
    // ========== أنواع الأطقم ==========
    'طقم كامل': ['full set', 'complete set', 'whole set', 'entire set'],
    'طقم نفر': ['single set', 'twin set', 'single bed set'],
    'طقم نفرين': ['double set', 'full set', 'double bed set'],
    'طقم كينج': ['king set', 'king size set', 'king bed set'],
    'طقم كوين': ['queen set', 'queen size set', 'queen bed set'],
    
    // ========== المفردات الموسمية ==========
    'صيفي': ['summer', 'warm weather', 'hot season', 'lightweight'],
    'شتوي': ['winter', 'cold season', 'warm', 'heavy', 'insulated'],
    'ربيعي': ['spring', 'spring season', 'floral', 'fresh'],
    'خريفي': ['autumn', 'fall', 'fall season', 'warm tones'],
    'كل الفصول': ['all season', 'year round', 'four seasons', 'any season'],
    
    // ========== مفردات السعر والقيمة ==========
    'سعر مناسب': ['reasonable price', 'fair price', 'good price', 'moderate price'],
    'قيمة مقابل السعر': ['value for money', 'bang for buck', 'worth it', 'good deal'],
    'جودة وسعر': ['quality and price', 'best value', '性价比'],
    
    // ========== أنواع النجف والإضاءة ==========
    'نجف': ['chandelier', 'ceiling lamp', 'pendant', 'hanging lamp', 'crystal chandelier'],
    'فانوس': ['lantern', 'lamp', 'light fixture', ' Arabic lamp', 'moroccan lamp'],
    'اضاءة داخلية': ['indoor lighting', 'interior lighting', 'home lighting'],
    'اضاءة خارجية': ['outdoor lighting', 'exterior lighting', 'garden lighting'],
    'لمبات led': ['led bulbs', 'led lights', 'energy saving lights', '节能灯'],
    'اضاءة خافتة': ['dim lighting', 'soft lighting', 'ambient lighting', 'mood lighting'],
    'اضاءة ساطعة': ['bright lighting', 'strong lighting', 'task lighting'],
    
    // ========== أنواع المكيفات والتدفئة ==========
    'مكيف': ['air conditioner', 'ac', 'cooling unit', 'climate control'],
    'مكيف سبليت': ['split ac', 'split unit', 'wall mounted ac'],
    'مكيف شباك': ['window ac', 'window unit'],
    'مدفأة': ['heater', 'fireplace', 'stove', 'warming unit'],
    'دفاية': ['electric heater', 'space heater', 'room heater'],
    
    // ========== مفردات الأمان والحماية ==========
    'واقي': ['protector', 'guard', 'shield', 'cover', 'pad'],
    'حماية': ['protection', 'safeguard', 'security', 'safety'],
    'مانع انزلاق': ['non slip', 'anti slip', 'grip', '防滑'],
    'مانع ماء': ['waterproof', 'water resistant', 'water repellent'],
    'مانع غبار': ['dustproof', 'dust resistant', 'dust cover'],
    
    // ========== أنواع الموسيقى والصوت ==========
    'سماعة': ['speaker', 'headphones', 'earphones', 'audio device'],
    'سماعات': ['speakers', 'headphones', 'earphones', 'audio equipment'],
    'صوت': ['sound', 'audio', 'noise', 'acoustics'],
    'موسيقى': ['music', 'melody', 'tunes', 'songs'],
    
    // ========== مفردات الطاقة والكهرباء ==========
    'كهربائي': ['electric', 'electrical', 'powered', 'electronic'],
    'يدوي': ['manual', 'hand operated', 'mechanical', 'non electric'],
    'بطارية': ['battery', 'cell', 'power cell', 'rechargeable'],
    'شاحن': ['charger', 'charging unit', 'power adapter'],
    'سلك': ['cable', 'cord', 'wire', 'line'],
    'فيش': ['plug', 'socket', 'outlet', 'connector'],
    
    // ========== مفردات التخزين والتنظيم ==========
    'تنظيم': ['organization', 'organizing', 'storage', 'arrangement', 'order'],
    'تخزين': ['storage', 'storing', 'keeping', 'housing', 'reservoir'],
    'منظم': ['organizer', 'arranger', 'container', 'holder'],
    'سلة': ['basket', 'hamper', 'bin', 'container'],
    'صندوق': ['box', 'chest', 'crate', 'case', 'trunk'],
    'ادراج': ['drawers', 'drawer', 'compartment', 'cabinet drawer'],
    
    // ========== مفردات النظافة والعناية ==========
    'نظافة': ['cleanliness', 'cleaning', 'hygiene', 'sanitation', 'purity'],
    'تنظيف': ['cleaning', 'washing', 'cleansing', 'purifying'],
    'غسيل': ['washing', 'laundry', 'cleaning', 'wash'],
    'كي': ['ironing', 'press', 'steam'],
    'عناية': ['care', 'maintenance', 'attention', 'treatment'],
    
    // ========== مفردات الزينة والتزيين ==========
    'زفاف': ['wedding', 'marriage', 'nuptials', 'bridal', 'matrimony'],
    'عروس': ['bride', 'bridal', 'newlywed', 'wife'],
    'خطوبة': ['engagement', 'betrothal', 'proposal', 'fiancé'],
    'ملكة': ['henna night', 'bridal shower', 'bachelorette'],
    'وليمة': ['feast', 'banquet', 'dinner party', 'reception'],
    
    // ========== مفردات العائلة والعلاقات ==========
    'عائلة': ['family', 'household', 'kin', 'relatives', 'clan'],
    'بيت': ['house', 'home', 'dwelling', 'residence', 'abode'],
    'منزل': ['home', 'house', 'residence', 'dwelling', 'habitat'],
    'سكن': ['housing', 'accommodation', 'residence', 'dwelling'],
    'سكني': ['residential', 'domestic', 'home', 'housing'],
    
    // ========== مفردات الزمن والوقت ==========
    'فوري': ['immediate', 'instant', 'urgent', 'prompt', 'quick'],
    'سريع': ['fast', 'quick', 'rapid', 'swift', 'speedy'],
    'يومي': ['daily', 'everyday', 'day to day', 'regular'],
    'اسبوعي': ['weekly', 'hebdomadal', 'seven days'],
    'شهري': ['monthly', 'mensual', 'per month'],
    'سنوي': ['yearly', 'annual', 'per year'],
    
    // ========== مفردات النسبة والمقارنة ==========
    'أفضل': ['best', 'better', 'superior', 'top', 'finest', 'optimal'],
    'الأحسن': ['the best', 'best', 'optimal', 'ideal'],
    'مقارنة': ['comparison', 'compare', 'versus', 'contrast'],
    'مشابه': ['similar', 'alike', 'comparable', 'analogous'],
    'بديل': ['alternative', 'substitute', 'replacement', 'option'],
    
    // ========== مفردات الطلب والشراء ==========
    'شراء': ['buy', 'purchase', 'acquire', 'get', 'obtain'],
    'اشتري': ['buy', 'purchase', 'get'],
    'اطلب': ['order', 'request', 'demand', 'ask for'],
    'احجز': ['reserve', 'book', 'pre order', 'hold'],
    'تسوق': ['shop', 'shopping', 'buying', 'purchasing'],
    'سلة مشتريات': ['shopping cart', 'cart', 'basket', 'bag'],
    
    // ========== مفردات الدفع والمال ==========
    'دفع': ['payment', 'pay', 'settlement', 'remittance'],
    'كاش': ['cash', 'money', 'currency', 'notes'],
    'فيزا': ['visa', 'credit card', 'card', 'plastic'],
    'ماستركارد': ['mastercard', 'credit card', 'card'],
    'تحويل بنكي': ['bank transfer', 'wire transfer', 'eft', 'bank deposit'],
    'الدفع عند الاستلام': ['cod', 'cash on delivery', 'pay on delivery'],
    'تقسيط': ['installments', 'installment', 'emi', 'monthly payments', '分期付款'],
    
    // ========== مفردات الواقع المعزز والتقنية ==========
    'ذكي': ['smart', 'intelligent', 'clever', 'bright', 'brainy'],
    'ذكية': ['smart', 'intelligent', 'clever'],
    'المنزل الذكي': ['smart home', 'home automation', 'intelligent home', 'connected home'],
    'تحكم': ['control', 'command', 'manage', 'operate', 'regulate'],
    'عن بعد': ['remote', 'distant', 'far', 'tele'],
    'بلوتوث': ['bluetooth', 'wireless', 'bt'],
    'واي فاي': ['wifi', 'wi fi', 'wireless internet', 'wlan'],
    
    // ========== مفردات البيئة والاستدامة ==========
    'صديق للبيئة': ['eco friendly', 'environmentally friendly', 'green', 'sustainable', 'eco'],
    'قابل لإعادة التدوير': ['recyclable', 'recycled', 'reusable', 'green'],
    'عضوي': ['organic', 'natural', 'biological', 'chemical free'],
    'طبيعي 100%': ['100% natural', 'pure natural', 'all natural'],
    'خالٍ من الكيماويات': ['chemical free', 'non toxic', 'natural', 'safe'],
    
    // ========== مفردات الحجم والكمية ==========
    'قطعة': ['piece', 'item', 'unit', 'part', 'component'],
    'قطع': ['pieces', 'items', 'units', 'parts'],
    'حبة': ['piece', 'item', 'unit', 'each'],
    'حبات': ['pieces', 'items', 'units', 'count'],
    'زوج': ['pair', 'couple', 'set of two', 'duo'],
    'مجموعة': ['set', 'collection', 'group', 'kit', 'pack'],
    'عبوة': ['pack', 'package', 'container', 'bottle', 'jar'],
    
    // ========== مفردات الاستخدام والوظيفة ==========
    'استخدام': ['use', 'usage', 'utilization', 'application', 'employment'],
    'وظيفة': ['function', 'purpose', 'role', 'job', 'task'],
    'غرض': ['purpose', 'aim', 'objective', 'goal', 'intent'],
    'فائدة': ['benefit', 'advantage', 'use', 'good', 'profit'],
    'استعمال': ['use', 'usage', 'utilization', 'employment', 'application'],
    
    // ========== مفردات الحالة والحالة الجديدة ==========
    'جديد تماما': ['brand new', 'brand new condition', 'mint condition', 'pristine'],
    'كالجديد': ['like new', 'as good as new', 'excellent condition', 'mint'],
    'مستعمل': ['used', 'second hand', 'pre owned', 'previously owned'],
    'بحالة ممتازة': ['excellent condition', 'great condition', 'very good'],
    'بحالة جيدة': ['good condition', 'fair condition', 'acceptable'],
    
    // ========== مفردات التقييم والمراجعات ==========
    'تقييم': ['rating', 'review', 'evaluation', 'assessment', 'appraisal'],
    'مراجعة': ['review', 'feedback', 'comment', 'testimonial', 'critique'],
    'رأي': ['opinion', 'view', 'thought', 'sentiment', 'judgment'],
    'تعليق': ['comment', 'remark', 'note', 'observation', 'statement'],
    
    // ========== مفردات الخصوصية والأمان ==========
    'خصوصية': ['privacy', 'seclusion', 'solitude', 'confidentiality'],
    'امن': ['security', 'safety', 'protection', 'safekeeping'],
    'آمن': ['safe', 'secure', 'protected', 'harmless'],
    'مؤمن': ['insured', 'secured', 'protected', 'guaranteed'],
    'مغلق': ['closed', 'shut', 'locked', 'sealed'],
    'مفتوح': ['open', 'unlocked', 'unsealed', 'accessible'],
    
    // ========== مفردات الشكل والتصميم ==========
    'دائري': ['circular', 'round', 'circle', 'ring', 'spherical'],
    'مربع': ['square', 'quadrilateral', 'boxy', 'rectangular'],
    'مستطيل': ['rectangular', 'oblong', 'rectangle', 'elongated'],
    'بيضاوي': ['oval', 'elliptical', 'egg shaped', 'oblong circle'],
    'مثلث': ['triangular', 'triangle', 'three sided', 'delta'],
    'مضلع': ['polygon', 'multisided', 'geometric'],
    'قوس': ['arch', 'curve', 'bow', 'arc'],
    'منحني': ['curved', 'bent', 'arched', 'rounded'],
    'مستقيم': ['straight', 'linear', 'direct', 'unaltered'],
    
    // ========== مفردات النمط والبناء ==========
    'نمط': ['pattern', 'design', 'style', 'motif', 'model'],
    'طباعة': ['printing', 'print', 'impression', 'pattern'],
    'مطرز': ['embroidered', 'stitched', 'needlework', 'embroidery'],
    'مخطط': ['striped', 'lined', 'streaked', 'banded'],
    'منقط': ['dotted', 'spotted', 'polka dot', 'speckled'],
    'مزخرف': ['decorated', 'ornamented', 'embellished', 'adorned'],
    'بسيط': ['plain', 'simple', 'unadorned', 'unpatterned', 'solid'],
    'مقلم': ['checkered', 'plaid', 'tartan', 'gingham', 'check'],
    
    // ========== مفردات السطح والملمس ==========
    'خشن': ['rough', 'coarse', 'harsh', 'uneven', 'rugged'],
    'لامع': ['shiny', 'glossy', 'lustrous', 'bright', 'polished'],
    'مطفي': ['matte', 'dull', 'flat', 'non shiny', 'satin'],
    'مخملي': ['velvety', 'velvet like', 'plush', 'soft'],
    'مطاطي': ['rubbery', 'elastic', 'stretchy', 'flexible'],
    'صلب': ['hard', 'solid', 'rigid', 'stiff', 'firm'],
    'طري': ['soft', 'tender', 'malleable', 'pliable'],
    
    // ========== مفردات الأبعاد والشكل ==========
    'طول': ['length', 'long', 'elongation', 'extent'],
    'عرض البعد': ['width', 'broad', 'breadth', 'wide'],
    'ارتفاع': ['height', 'tall', 'elevation', 'altitude'],
    'عمق': ['depth', 'deep', 'profoundness', 'penetration'],
    'سماكة': ['thickness', 'thick', 'density', 'bulk'],
    'رقيقة': ['thin', 'slender', 'fine', 'narrow', 'slim'],
    'سميكة': ['thick', 'heavy', 'bulky', 'dense', 'chunky'],
    'جانب': ['side', 'lateral', 'flank', 'edge', 'border'],
    'امام': ['front', 'forward', 'fore', 'anterior', 'face'],
    'خلف': ['back', 'rear', 'behind', 'posterior', 'reverse'],
    
    // ========== مفردات الحركة والتغيير ==========
    'قابل للطي': ['foldable', 'folding', 'collapsible', 'compact'],
    'قابل للتمدد': ['extendable', 'extensible', 'expandable', 'stretchable'],
    'قابل للتعديل': ['adjustable', 'adaptable', 'modifiable', 'flexible'],
    'قابل للازالة': ['removable', 'detachable', 'separable', 'portable'],
    'ثابت': ['fixed', 'stationary', 'permanent', 'immovable', 'stable'],
    'متحرك': ['movable', 'mobile', 'portable', 'transportable'],
    'مرن': ['flexible', 'elastic', 'pliable', 'adaptable', 'pliant'],
    
    // ========== مفردات الحماية والمتانة ==========
    'متين': ['durable', 'strong', 'sturdy', 'robust', 'tough'],
    'قوي': ['strong', 'powerful', 'potent', 'mighty', 'sturdy'],
    'ضعيف': ['weak', 'fragile', 'delicate', 'frail', 'feeble'],
    'هش': ['brittle', 'fragile', 'delicate', 'breakable', 'frail'],
    'قابل للكسر': ['breakable', 'fragile', 'brittle', 'delicate'],
    'قابل للخدش': ['scratchable', 'vulnerable', 'susceptible'],
    'مقاوم للخدش': ['scratch resistant', 'durable', 'tough', 'hard wearing'],
    
    // ========== مفردات التركيب والتجميع ==========
    'سهل التركيب': ['easy to install', 'simple assembly', 'quick setup'],
    'جاهز للاستخدام': ['ready to use', 'pre assembled', 'rtu', 'plug and play'],
    'يتطلب تركيب': ['requires assembly', 'assembly required', 'needs installation'],
    'مجمع': ['assembled', 'put together', 'constructed', 'built'],
    'مفكك': ['disassembled', 'taken apart', 'knocked down', 'flat pack'],
    
    // ========== مفردات الوصف العام ==========
    'جميل': ['beautiful', 'pretty', 'lovely', 'attractive', 'gorgeous', 'stunning'],
    'انيق': ['elegant', 'stylish', 'chic', 'graceful', 'refined', 'sophisticated'],
    'جذاب': ['attractive', 'appealing', 'charming', 'alluring', 'captivating'],
    'مميز': ['distinctive', 'unique', 'special', 'exceptional', 'outstanding', 'distinguished'],
    'عادي': ['ordinary', 'regular', 'normal', 'standard', 'common', 'usual'],
    'مثالي': ['ideal', 'perfect', 'optimal', 'excellent', 'flawless', 'impeccable'],
    'عملي': ['practical', 'functional', 'useful', 'utilitarian', 'handy', 'convenient'],
    'معقد': ['complex', 'complicated', 'intricate', 'elaborate', 'sophisticated'],
    'حديث': ['modern', 'new', 'recent', 'contemporary', 'current', 'latest'],
    'قديم': ['old', 'ancient', 'antique', 'vintage', 'dated', 'outdated'],
    'عتيق': ['antique', 'vintage', 'old', 'classic', 'heritage', 'timeless'],
    
    // ========== أنواع الخامات الخاصة ==========
    'مخمل هولندي': ['dutch velvet', 'imported velvet', 'premium velvet'],
    'قطن مصري': ['egyptian cotton', 'premium cotton', 'long staple cotton'],
    'حرير طبيعي': ['natural silk', 'pure silk', 'mulberry silk', 'real silk'],
    'صوف مرينو': ['merino wool', 'fine wool', 'soft wool', 'premium wool'],
    'جلد ايطالي': ['italian leather', 'premium leather', 'fine leather', 'luxury leather'],
    'خشب زان': ['beech wood', 'hardwood', 'quality wood'],
    'خشب موسكي': ['walnut wood', 'dark wood', 'premium wood'],
    'خشب ارو': ['teak wood', 'durable wood', 'water resistant wood'],
    'رخام': ['marble', 'natural stone', 'stone'],
    'جرانيت': ['granite', 'natural stone', 'hard stone'],
    'كوارتز': ['quartz', 'engineered stone', 'silestone'],
    'سيراميك': ['ceramic', 'porcelain', 'tiles'],
    'بورسلين': ['porcelain', 'fine china', 'ceramic'],
    'ستانلس': ['stainless', 'inox', 'ssteel', 'corrosion resistant'],
    'المونيوم': ['aluminum', 'aluminium', 'light metal'],
    'نحاس': ['copper', 'brass', 'bronze', 'metal'],
    
    // ========== أنواع الطلاء والتشطيب ==========
    'طلاء': ['paint', 'coating', 'finish', 'varnish', 'lacquer'],
    'ورنيش': ['varnish', 'lacquer', 'shellac', 'coating'],
    'دهان': ['paint', 'color', 'pigment', 'dye'],
    'خشب طبيعي': ['natural wood', 'raw wood', 'unfinished wood', 'solid wood'],
    'خشب ملون': ['stained wood', 'colored wood', 'dyed wood'],
    'خشب مطلي': ['painted wood', 'coated wood', 'finished wood'],
    'معدن مطلي': ['coated metal', 'painted metal', 'finished metal', 'powder coated'],
    
    // ========== أنواع المفصلات والاكسسوارات ==========
    'مفصلة': ['hinge', 'joint', 'pivot', 'connector'],
    'قفل': ['lock', 'latch', 'bolt', 'fastener'],
    'مقبض': ['handle', 'knob', 'pull', 'grip'],
    'يد': ['handle', 'arm', 'handhold'],
    'رجل': ['leg', 'foot', 'stand', 'support'],
    'قاعدة': ['base', 'foundation', 'bottom', 'stand', 'pedestal'],
    
    // ========== أنواع الإضاءة الخاصة ==========
    'اضاءة طبيعية': ['natural light', 'daylight', 'sunlight', 'ambient light'],
    'اضاءة صناعية': ['artificial light', 'electric light', 'lamp light'],
    'اضاءة led': ['led lighting', 'led light', 'energy efficient light'],
    'اضاءة هالوجين': ['halogen light', 'halogen lamp', 'bright light'],
    'اضاءة فلورسنت': ['fluorescent light', 'tube light', 'cfl'],
    'اضاءة ذكية': ['smart lighting', 'connected light', 'wifi light', 'bluetooth light'],
    'اضاءة ملونة': ['color changing light', 'rgb light', 'mood light'],
    'اضاءة قابلة للتعتيم': ['dimmable light', 'adjustable light', 'dimmer light'],
    
    // ========== أنواع التكييف والتهوية ==========
    'تكييف مركزي': ['central ac', 'hvac', 'ducted ac', 'split ducted'],
    'مكيف متنقل': ['portable ac', 'mobile ac', 'standing ac', 'movable ac'],
    'مروحة': ['fan', 'blower', 'ventilator', 'air circulator'],
    'مروحة سقف': ['ceiling fan', 'overhead fan', 'roof fan'],
    'مروحة عمودية': ['standing fan', 'pedestal fan', 'tower fan'],
    'مروحة طاولة': ['table fan', 'desk fan', 'small fan'],
    'فتحة تهوية': ['vent', 'air vent', 'ventilation opening', 'exhaust'],
    'شفاط': ['extractor', 'hood', 'range hood', 'ventilation hood'],
    
    // ========== أنواع العزل والحماية ==========
    'عزل حراري': ['thermal insulation', 'heat insulation', 'temperature control'],
    'عزل صوتي': ['sound insulation', 'acoustic insulation', 'noise reduction'],
    'عزل مائي': ['waterproofing', 'moisture barrier', 'damp proofing'],
    'مادة عازلة': ['insulator', 'insulating material', 'barrier material'],
    
    // ========== أنواع التخزين الذكي ==========
    'خزانة ذكية': ['smart closet', 'intelligent wardrobe', 'automated cabinet'],
    'رف كهربائي': ['motorized shelf', 'electric shelf', 'automated shelf'],
    'ادراج ذكية': ['smart drawer', 'intelligent drawer', 'soft close drawer'],
    'نظام تخزين': ['storage system', 'organization system', 'modular storage'],
    
    // ========== أنواع المراتب الذكية ==========
    'مرتبة ذكية': ['smart mattress', 'intelligent bed', 'connected mattress'],
    'مرتبة قابلة للتعديل': ['adjustable mattress', 'flexible bed', 'customizable mattress'],
    'قاعدة قابلة للتعديل': ['adjustable base', 'flexible foundation', 'electric bed base'],
    'سرير كهربائي': ['electric bed', 'motorized bed', 'power bed'],
    
    // ========== أنواع الأثاث متعدد الوظائف ==========
    'اثاث متعدد': ['multifunctional furniture', 'convertible furniture', 'transformable furniture'],
    'كنب يتحول': ['convertible sofa', 'transformable couch', 'sofa bed'],
    'طاولة تتحول': ['convertible table', 'transformable desk', 'folding table'],
    'سرير مخفي': ['murphy bed', 'wall bed', 'hidden bed', 'folding bed'],
    'خزانة تتحول': ['convertible cabinet', 'transformable wardrobe', 'multipurpose storage'],
    
    // ========== أنواع التقنيات الحديثة ==========
    'شاحن لاسلكي': ['wireless charger', 'qi charger', 'inductive charger'],
    'منفذ usb': ['usb port', 'charging port', 'usb outlet'],
    'تطبيق': ['app', 'application', 'software', 'program'],
    'تحكم صوتي': ['voice control', 'speech control', 'voice command'],
    'مساعد ذكي': ['smart assistant', 'ai assistant', 'virtual assistant', 'alexa', 'siri', 'google assistant'],
    
    // ========== أنواع الأمان الذكي ==========
    'قفل ذكي': ['smart lock', 'digital lock', 'electronic lock', 'keyless lock'],
    'كاميرا': ['camera', 'webcam', 'security camera', 'surveillance'],
    'حساس': ['sensor', 'detector', 'motion sensor', 'presence sensor'],
    'انذار': ['alarm', 'alert', 'warning', 'siren'],
    'جهاز استشعار': ['sensor device', 'detector', 'sensing device'],
    
    // ========== أنواع الطاقة الشمسية ==========
    'طاقة شمسية': ['solar power', 'solar energy', 'photovoltaic'],
    'لوح شمسي': ['solar panel', 'pv panel', 'photovoltaic panel'],
    'شاحن شمسي': ['solar charger', 'sun charger', 'solar powered'],
    'انارة شمسية': ['solar light', 'sun powered light', 'solar lamp'],
    
    // ========== أنواع التبريد والتدفئة ==========
    'مبرد ماء': ['water cooler', 'water chiller', 'dispenser'],
    'دفاية زيت': ['oil heater', 'radiator heater', 'oil filled radiator'],
    'دفاية كهربائية': ['electric heater', 'space heater', 'room heater'],
    'دفاية غاز': ['gas heater', 'lpg heater', 'natural gas heater'],
    'مدفأة كهربائية': ['electric fireplace', 'flame effect heater', 'led fireplace'],
    
    // ========== أنواع التنظيف والتعقيم ==========
    'بخار': ['steam', 'vapor', 'steam cleaning', 'vapor cleaning'],
    'تعقيم': ['sterilization', 'disinfection', 'sanitization', 'germ free'],
    'تطهير': ['sanitizing', 'cleansing', 'purifying', 'disinfecting'],
    'مضاد بكتيريا': ['antibacterial', 'germ resistant', 'microbe resistant'],
    'مانع فطريات': ['anti fungal', 'mold resistant', 'mildew resistant'],
    
    // ========== أنواع الراحة والدعم ==========
    'دعم قطني': ['lumbar support', 'back support', 'lower back support'],
    'دعم رقبة': ['neck support', 'cervical support', 'neck pillow'],
    'مقعد مريح': ['comfortable seat', 'ergonomic seat', 'padded seat'],
    'مسند': ['support', 'rest', 'backrest', 'armrest', 'headrest'],
    
    // ========== أنواع الحركة والتعديل ==========
    'ارتفاع قابل للتعديل': ['adjustable height', 'height adjustable', 'variable height'],
    'زاوية قابلة للتعديل': ['adjustable angle', 'tiltable', 'reclining'],
    'دوران': ['rotation', 'swivel', 'turning', 'pivoting'],
    'قابل للدوران': ['swivel', 'rotatable', 'turnable', 'revolving'],
    'قفل العجلات': ['wheel lock', 'caster lock', 'brake'],
    
    // ========== أنواع المقابض والتحكم ==========
    'زر ضغط': ['push button', 'press button', 'click button'],
    'مقبض دوار': ['knob', 'rotary knob', 'turning handle'],
    'شاشة لمس': ['touch screen', 'touch display', 'touch panel'],
    'تحكم عن بعد': ['remote control', 'wireless remote', 'controller'],
    
    // ========== أنواع المواد المستدامة ==========
    'خشب مستصلح': ['reclaimed wood', 'recycled wood', 'upcycled wood'],
    'بلاستيك معاد تدويره': ['recycled plastic', 'rpet', 'upcycled plastic'],
    'اقمشه عضوية': ['organic fabrics', 'natural textiles', 'eco fabrics'],
    'صبغات طبيعية': ['natural dyes', 'plant based dyes', 'organic colors'],
    
    // ========== أنواع التعبئة المستدامة ==========
    'تغليف قابل لإعادة التدوير': ['recyclable packaging', 'eco packaging', 'green packaging'],
    'تغليف قابل للتحلل': ['biodegradable packaging', 'compostable packaging', 'eco friendly packaging'],
    'بدون بلاستيك': ['plastic free', 'zero plastic', 'no plastic'],
    'مواد طبيعية': ['natural materials', 'organic materials', 'biological materials'],
    
    // ========== أوصاف المنتجات الإضافية ==========
    'خفيف الوزن': ['lightweight', 'light', 'portable', 'easy to carry'],
    'ثقيل الوزن': ['heavyweight', 'heavy', 'substantial', 'solid'],
    'سهل الحمل': ['easy to carry', 'portable', 'transportable', 'mobile'],
    'صعب الحركة': ['hard to move', 'heavy', 'immovable', 'fixed'],
    'قابل للغسل': ['washable', 'machine washable', 'easy clean'],
    'غير قابل للغسل': ['non washable', 'dry clean only', 'spot clean only'],
    'يحتاج لتجميع': ['assembly required', 'needs assembly', 'diy assembly'],
    'جاهز للاستعمال': ['ready to use', 'pre assembled', 'fully assembled'],
    
    // ========== أنواع الخدمات الإضافية ==========
    'تركيب مجاني': ['free installation', 'complimentary installation', 'included installation'],
    'ضمان شامل': ['full warranty', 'comprehensive warranty', 'complete coverage'],
    'صيانة دورية': ['periodic maintenance', 'regular maintenance', 'scheduled service'],
    'خدمة عملاء': ['customer service', 'customer support', 'help desk'],
    'استشارة مجانية': ['free consultation', 'complimentary advice', 'expert consultation'],
    
    // ========== أوصاف المخزون والتوفر ==========
    'متوفر': ['available', 'in stock', 'on hand', 'ready'],
    'غير متوفر': ['unavailable', 'out of stock', 'sold out', 'not available'],
    'محدود': ['limited', 'scarce', 'few', 'restricted'],
    'كثير': ['abundant', 'plenty', 'many', 'ample'],
    'تحت الطلب': ['made to order', 'custom order', 'bespoke', 'on demand'],
    'وقت التوصيل': ['delivery time', 'lead time', 'shipping time', 'transit time'],
    
    // ========== أنواع العروض والحزم ==========
    'حزمة': ['bundle', 'package', 'kit', 'set', 'combo'],
    'عبوة اقتصادية': ['economy pack', 'value pack', 'bulk pack', 'family pack'],
    'عبوة عائلية': ['family pack', 'household pack', 'large pack'],
    'عبوة فردية': ['single pack', 'individual pack', 'personal pack'],
    'اشتراك': ['subscription', 'membership', 'plan', 'service agreement'],
    
    // ========== أوصاف الشحن والتوصيل ==========
    'شحن سريع': ['fast shipping', 'express delivery', 'quick shipping'],
    'شحن دولي': ['international shipping', 'worldwide shipping', 'global delivery'],
    'توصيل محلي': ['local delivery', 'domestic shipping', 'in country delivery'],
    'استلام من المتجر': ['store pickup', 'click and collect', 'in store pickup'],
    
    // ========== أنواع الدفع ==========
    'دفع الكتروني': ['electronic payment', 'e payment', 'digital payment'],
    'بطاقة ائتمان': ['credit card', 'charge card', 'plastic'],
    'بطاقة خصم': ['debit card', 'check card', 'bank card'],
    'محفظة الكترونية': ['e wallet', 'digital wallet', 'mobile wallet'],
    'apple pay': ['apple payment', 'ios payment', 'iphone payment'],
    'google pay': ['google payment', 'android payment', 'gpay'],
    
    // ========== أنواع الخصومات ==========
    'خصم نسبة': ['percentage discount', 'percent off', '% off'],
    'خصم مبلغ': ['amount discount', 'fixed discount', 'flat discount'],
    'خصم موسمي': ['seasonal discount', 'holiday discount', 'promotional discount'],
    'خصم اول شراء': ['first purchase discount', 'new customer discount', 'welcome discount'],
    'خصم كمية': ['volume discount', 'bulk discount', 'quantity discount'],
    'كوبون': ['coupon', 'voucher', 'promo code', 'discount code'],
    'رمز ترويجي': ['promo code', 'promotional code', 'coupon code'],
    
    // ========== أنواع العضويات ==========
    'عضوية': ['membership', 'subscription', 'enrollment'],
    'عميل مميز': ['vip customer', 'preferred customer', 'elite member'],
    'نقاط مكافآت': ['reward points', 'loyalty points', 'bonus points'],
    'برنامج ولاء': ['loyalty program', 'rewards program', 'frequent buyer program'],
    
    // ========== أنواع المراجعات ==========
    'تقييم ايجابي': ['positive review', 'good review', 'favorable review', '5 star'],
    'تقييم سلبي': ['negative review', 'bad review', 'poor review', '1 star'],
    'تقييم محايد': ['neutral review', 'average review', '3 star'],
    'شهادة': ['testimonial', 'endorsement', 'recommendation'],
    'تجربة شراء': ['purchase experience', 'buying experience', 'shopping experience'],
    
    // ========== أنواع المقارنات ==========
    'مقارنة السعر': ['price comparison', 'compare prices', 'price match'],
    'مقارنة المنتجات': ['product comparison', 'compare items', 'side by side'],
    'بديل أرخص': ['cheaper alternative', 'budget alternative', 'affordable option'],
    'بديل أعلى جودة': ['premium alternative', 'upgraded version', 'luxury option'],
    
    // ========== أوصاف المستخدم ==========
    'مستخدم اول مرة': ['first time user', 'new user', 'beginner', 'novice'],
    'مستخدم متمرس': ['experienced user', 'advanced user', 'expert user'],
    'عميل دائم': ['regular customer', 'frequent buyer', 'loyal customer'],
    'زائر جديد': ['new visitor', 'first time visitor', 'prospect'],
    
    // ========== أنواع الاستفسارات ==========
    'استفسار': ['inquiry', 'query', 'question', 'request'],
    'شكوى': ['complaint', 'grievance', 'issue', 'problem'],
    'اقتراح': ['suggestion', 'recommendation', 'idea', 'feedback'],
    'طلب مساعدة': ['help request', 'support request', 'assistance needed'],
    
    // ========== أنواع الدعم ==========
    'دعم فني': ['technical support', 'tech support', 'it support'],
    'دعم مبيعات': ['sales support', 'customer support', 'purchase help'],
    'دعم بعد البيع': ['after sales support', 'post purchase support', 'warranty support'],
    'دعم مباشر': ['live support', 'real time support', 'chat support'],
    
    // ========== أنواع المعلومات ==========
    'مواصفات': ['specifications', 'specs', 'technical details', 'features'],
    'تفاصيل': ['details', 'particulars', 'specifics', 'info'],
    'وصف': ['description', 'explanation', 'account', 'depiction'],
    'ارشادات': ['instructions', 'directions', 'guidelines', 'manual'],
    
    // ========== أنواع التحذيرات ==========
    'تحذير': ['warning', 'caution', 'alert', 'notice'],
    'احتياط': ['precaution', 'care', 'attention', 'heed'],
    'خطر': ['danger', 'hazard', 'risk', 'peril'],
    'انتباه': ['attention', 'notice', 'caution', 'alert'],
    
    // ========== أنواع النصائح ==========
    'نصيحة': ['tip', 'advice', 'suggestion', 'recommendation'],
    'تلميح': ['hint', 'clue', 'pointer', 'suggestion'],
    'ارشاد': ['guidance', 'direction', 'instruction', 'counsel'],
    'توصية': ['recommendation', 'suggestion', 'advice', 'proposal'],
    
    // ========== أوصاف النهاية ==========
  };

  /// تصحيح الأخطاء الشائعة في الكتابة - موسع
  static const Map<String, String> _commonTypos = {
    // الأخطاء الشائعة في المخدات والفرش
    'فراشة': 'فرشة',
    'فراشات': 'فرشات',
    'مخده': 'مخدة',
    'وساده': 'وسادة',
    'سجاده': 'سجادة',
    'طاوله': 'طاولة',
    'ترابيزه': 'ترابيزة',
    'ستاره': 'ستارة',
    'برداي': 'برداية',
    'بردايه': 'برداية',
    'فرشه': 'فرشة',
    'مرتبه': 'مرتبة',
    'وسايد': 'وسائد',
    'زوليه': 'زولية',
    
    // همزات وإملاء
    'اطفال': 'أطفال',
    'افرشة': 'فرشة',
    'اسجاد': 'سجاد',
    'استارة': 'ستارة',
    'ابرداية': 'برداية',
    'اكسسوار': 'اكسسوار',
    
    // أخطاء شائعة أخرى
    'بياضات': 'مفارش',
    'بياضة': 'مفرش',
    'مفارص': 'مفارش',
    'اطقم': 'أطقم',
    'اطقم كنب': 'أطقم كنب',
    
    // كلمات إنجليزية شائعة
    'bed': 'سرير',
    'mattress': 'مرتبة',
    'pillow': 'مخدة',
    'carpet': 'سجاد',
    'curtain': 'ستارة',
    'sofa': 'كنب',
  };

  /// البحث الذكي الرئيسي
  Future<List<Product>> smartSearch(String query) async {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return [];

    try {
      // 1. تصحيح الأخطاء الإملائية
      final correctedQuery = _correctTypos(trimmed);

      // 2. الحصول على المرادفات
      final synonyms = _getSynonyms(correctedQuery);

      // 3. البحث المتعدد
      final results = await _multiSearch(correctedQuery, synonyms);

      // 4. إذا لم نجد نتائج، نحاول البحث الغامض (fuzzy)
      if (results.isEmpty) {
        return await _fuzzySearch(correctedQuery);
      }

      return results;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Smart search error: $e');
      }
      return [];
    }
  }

  /// تصحيح الأخطاء الإملائية الشائعة
  String _correctTypos(String query) {
    // تحقق من الكلمات الفردية
    final words = query.split(' ');
    final corrected = words.map((word) {
      return _commonTypos[word] ?? word;
    }).join(' ');
    
    return corrected;
  }

  /// الحصول على كل المرادفات للكلمة
  List<String> _getSynonyms(String word) {
    final result = <String>{word}; // نضيف الكلمة الأصلية
    
    // البحث في قاموس المرادفات
    _synonyms.forEach((key, values) {
      if (word.contains(key) || key.contains(word)) {
        result.add(key);
        result.addAll(values);
      }
    });
    
    if (kDebugMode) {
      debugPrint('Search word: $word, Synonyms found: ${result.toList()}');
    }
    
    return result.toList();
  }

  /// البحث المتعدد في العنوان والوصف والمرادفات
  Future<List<Product>> _multiSearch(String query, List<String> synonyms) async {
    final Set<Product> uniqueProducts = {};
    
    // البحث بجميع الكلمات (الأصلية + المرادفات) بشكل متوازي
    final allTerms = <String>{query, ...synonyms};
    
    for (final term in allTerms) {
      final results = await _searchByTerm(term);
      uniqueProducts.addAll(results);
      
      // نكتفي بـ 30 منتج
      if (uniqueProducts.length >= 30) break;
    }
    
    return uniqueProducts.toList();
  }

  /// البحث بكلمة واحدة في العنوان والوصف والوسوم
  Future<List<Product>> _searchByTerm(String term) async {
    try {
      // البحث في العنوان والوصف والوسوم (tags)
      final data = await _supabase
          .from('products')
          .select()
          .eq('is_active', true)
          .or('title.ilike.%$term%,description.ilike.%$term%,tags.cs.{"$term"}')
          .limit(30);

      return data.map((e) => Product.fromJson(e)).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Search by term error: $e');
      }
      return [];
    }
  }

  /// البحث الغامض (fuzzy) - يبحث بأجزاء من الكلمة
  Future<List<Product>> _fuzzySearch(String query) async {
    try {
      // إذا كانت الكلمة قصيرة جداً، لا نبحث
      if (query.length < 3) return [];

      // نأخذ أول 3-4 أحرف ونبحث بها
      final prefix = query.substring(0, query.length >= 4 ? 4 : 3);

      final data = await _supabase
          .from('products')
          .select()
          .eq('is_active', true)
          .or('title.ilike.%$prefix%,description.ilike.%$prefix%,tags.cs.{"$prefix"}')
          .limit(20);

      return data.map((e) => Product.fromJson(e)).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Fuzzy search error: $e');
      }
      return [];
    }
  }

  /// البحث بالفئة (categories)
  Future<List<Product>> searchByCategory(String categoryId) async {
    try {
      final data = await _supabase
          .from('products')
          .select()
          .eq('is_active', true)
          .eq('category', categoryId)
          .limit(30);

      return data.map((e) => Product.fromJson(e)).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Category search error: $e');
      }
      return [];
    }
  }
}
