import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text_styles.dart';

/// 服務條款 / 隱私權政策 兩個分頁
enum PolicyTab { terms, privacy }

/// 在任何頁面呼叫即可開啟:showPolicyDialog(context);
Future<void> showPolicyDialog(
  BuildContext context, {
  PolicyTab initialTab = PolicyTab.terms,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '關閉條款',
    barrierColor: AppColors.dialogBarrier,
    transitionDuration: const Duration(milliseconds: 260),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final CurvedAnimation curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
      );

      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) {
      return SafeArea(
        child: Center(child: PolicyDialog(initialTab: initialTab)),
      );
    },
  );
}

/// 註冊頁用的「點擊註冊即表示您同意…」小字,兩個連結可點開條款
class PolicyConsentText extends StatelessWidget {
  final String actionLabel;

  const PolicyConsentText({super.key, this.actionLabel = '註冊'});

  @override
  Widget build(BuildContext context) {
    final TextStyle base = AppTextStyles.bodySmall.copyWith(
      fontSize: 10.5,
      color: AppColors.textPrimary,
    );

    Widget link(String text, PolicyTab tab) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showPolicyDialog(context, initialTab: tab),
        child: Text(
          text,
          style: base.copyWith(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            decoration: TextDecoration.underline,
          ),
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('$actionLabel此服務即表示您同意', style: base),
        link('《服務條款》', PolicyTab.terms),
        Text('與', style: base),
        link('《隱私權政策》', PolicyTab.privacy),
      ],
    );
  }
}

class PolicyDialog extends StatefulWidget {
  final PolicyTab initialTab;

  const PolicyDialog({super.key, this.initialTab = PolicyTab.terms});

  @override
  State<PolicyDialog> createState() => _PolicyDialogState();
}

class _PolicyDialogState extends State<PolicyDialog> {
  late PolicyTab tab = widget.initialTab;
  final ScrollController scrollController = ScrollController();

  @override
  void dispose() {
    scrollController.dispose();
    super.dispose();
  }

  void _switchTab(PolicyTab next) {
    if (next == tab) return;

    setState(() {
      tab = next;
    });

    if (scrollController.hasClients) {
      scrollController.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final double width = size.width < 360 ? size.width - 32 : 328;
    final double height = (size.height * 0.82).clamp(360.0, 640.0).toDouble();
    final List<_Article> articles = tab == PolicyTab.terms
        ? _termsArticles
        : _privacyArticles;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.postcardLine, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(context),
            _buildTabs(),
            Expanded(child: _buildContent(articles)),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 12, 6, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.primaryLight, AppColors.primary],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: Colors.white, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '服務條款與隱私權政策',
                  style: AppTextStyles.bodyEmphasisBold.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '日遊所思夜遊所夢團隊 ・ 更新於 $_lastUpdated',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '關閉',
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: AppColors.postcard.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            _tabButton('服務條款', PolicyTab.terms),
            _tabButton('隱私權政策', PolicyTab.privacy),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(String label, PolicyTab value) {
    final bool selected = tab == value;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _switchTab(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(19),
          ),
          child: Text(
            label,
            style: AppTextStyles.bodySmallBold.copyWith(
              color: selected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(List<_Article> articles) {
    return Scrollbar(
      controller: scrollController,
      thumbVisibility: true,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        children: [
          _buildConsentBox(),
          for (int i = 0; i < articles.length; i++)
            _buildArticle(i + 1, articles[i]),
        ],
      ),
    );
  }

  Widget _buildConsentBox() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.postcard.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.postcardLine, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '註冊或使用本服務，即視為您已閱讀、瞭解並同意以下全部內容，包含但不限於各條款所列之規範。',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
                height: 1.5,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArticle(int index, _Article article) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$index',
                  style: AppTextStyles.captionBold.copyWith(
                    color: Colors.white,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  article.title,
                  style: AppTextStyles.bodySmallBold.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Text(
              article.body,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
                height: 1.6,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppColors.postcardLine.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => Navigator.of(context).pop(),
          borderRadius: BorderRadius.circular(25),
          child: Container(
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: AppColors.primaryDark, width: 2),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.primaryLight, AppColors.primary],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              '我已閱讀',
              style: AppTextStyles.subtitle.copyWith(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _Article {
  final String title;
  final String body;

  const _Article(this.title, this.body);
}

const String _lastUpdated = '2026 年 10 月 28 日';

const List<_Article> _termsArticles = [
  _Article(
    '總則與同意',
    '歡迎使用 PLAYTAIWAN（以下稱「本服務」），本服務由日遊所思夜遊所夢團隊（以下稱「本團隊」）提供。您完成註冊、登入或以任何方式使用本服務，即視為您已閱讀、瞭解並同意受本服務條款、隱私權政策及本團隊日後公告之相關規範（包含但不限於活動辦法、商家優惠規則與使用說明）拘束。若您不同意，請勿註冊或使用本服務。',
  ),
  _Article(
    '服務內容',
    '本服務提供之功能包含但不限於：AI 旅遊劇本生成、地圖與路線探險、NFC 與 QR Code 任務驗證、徽章蒐集、明信片與紀錄片（Vlog）、優惠券、喜愛劇本、組隊配對、AI 夥伴對話，以及商家端管理功能。本團隊得隨時新增、調整或停止部分功能，不另行個別通知。',
  ),
  _Article(
    '帳號註冊與安全',
    '您應提供真實、正確且完整的註冊資料，並於資料變更時儘速更新。帳號與密碼請自行妥善保管，不得轉讓、出借或與他人共用；以您的帳號所進行之一切行為，均視為您本人之行為。若發現帳號遭盜用，請立即與本團隊聯絡。',
  ),
  _Article(
    '使用者行為規範',
    '您同意不得從事下列行為：\n・違反法令或侵害他人權利（包含智慧財產權、隱私權、名譽權）；\n・上傳或輸入違法、暴力、色情、騷擾、歧視或其他不當內容；\n・以外掛、程式、偽造位置、複製 NFC 或 QR Code 等方式取得徽章、優惠或任務獎勵；\n・干擾、破壞或試圖未經授權存取本服務之系統與資料；\n・濫用 AI 功能，誘導生成違法或有害內容；\n・其他經本團隊合理判斷不適當之行為。',
  ),
  _Article(
    '使用者內容與授權',
    '您上傳或輸入之圖片、影片、文字與其他內容（以下稱「使用者內容」），其權利仍歸您或原權利人所有。您保證有權提供該內容，且不侵害任何第三人之權益。為提供、維護與改善本服務所必要，您同意授權本團隊於服務範圍內儲存、處理、重製與顯示該內容。',
  ),
  _Article(
    'AI 生成內容聲明',
    '本服務之劇本、對話與紀錄片等內容由 AI 模型自動生成。AI 生成內容僅供參考，不構成任何專業建議，請以現場實際情況與官方公告為準。',
  ),
  _Article(
    '外出活動與人身安全',
    '本服務之探險活動需在實際場域進行。請遵守交通規則與當地法令，避免於行進間操作手機，並留意天候、環境與人身財物安全；不得進入私人土地、管制或危險區域。因您外出活動所生之一切風險與損害，由您自行負責。',
  ),
  _Article(
    '優惠券與合作商家',
    '優惠券、折扣與活動內容由合作商家提供，實際內容、適用條件與有效期限以優惠券頁面及商家公告為準。商家得依其規定調整或終止優惠。本團隊為平台提供者，並非商品或服務之交易當事人，對商品或服務品質不負擔保責任；如有爭議請向商家洽詢。',
  ),
  _Article(
    '智慧財產權',
    '本服務之程式、介面設計、圖像、文字、角色、商標及其他內容，其智慧財產權均屬本團隊或原授權人所有。未經書面同意，不得重製、改作、散布、公開傳輸或為其他商業利用。',
  ),
  _Article(
    '服務變更、中止與終止',
    '本團隊得因系統維護、不可抗力或營運需要，暫停、變更或終止全部或部分服務。若您違反本條款，本團隊得不經通知，暫停或終止您的帳號與使用權限，並保留依法追訴之權利。',
  ),
  _Article(
    '免責聲明與責任限制',
    '本服務係依「現況」提供，本團隊不保證服務不中斷、無錯誤或完全符合您的期待。於法律允許之最大範圍內，本團隊對因使用或無法使用本服務所致之間接、附帶或衍生性損害，不負賠償責任。本條款不排除依法不得排除之責任。',
  ),
  _Article(
    '條款修訂',
    '本團隊得隨時修訂本條款，並公告於本服務中。修訂後您繼續使用本服務，即視為同意修訂內容；如不同意，請停止使用並可申請刪除帳號。',
  ),
  _Article(
    '準據法與管轄',
    '本條款以中華民國（臺灣）法律為準據法。因本服務所生之爭議，雙方應先本誠信協商；協商不成時，以臺灣有管轄權之法院為第一審管轄法院。',
  ),
  _Article('聯絡我們', '如對條款有任何疑問，歡迎聯絡來信：playtaiwan2026@gmail.com'),
];

const List<_Article> _privacyArticles = [
  _Article(
    '適用範圍與同意',
    '本政策說明日遊所思夜遊所夢團隊（以下稱「本團隊」）於您使用 PLAYTAIWAN 時，如何蒐集、處理與利用您的個人資料。您完成註冊或使用本服務，即視為您已閱讀並同意本政策，包含但不限於下列各條所載之蒐集、處理及利用行為。',
  ),
  _Article(
    '蒐集之個人資料類別',
    '・帳號資料：帳號名稱、電子信箱、密碼、生日、性別；\n・位置資料：使用附近景點、地圖與探險功能時之裝置位置；\n・相機與影像：掃描 QR Code 時使用相機；\n・相簿與上傳內容：您選擇上傳之圖片、影片，及儲存至相簿之 QR Code、明信片；\n・遊玩紀錄：劇本、任務進度、徽章、明信片、紀錄片、優惠券、喜愛劇本與組隊資訊；\n・AI 互動內容：您輸入之偏好、地點與對話內容；\n・裝置本機資料：登入狀態、角色頭像選擇與快取資料；\n・商家帳號：商家資訊、優惠券與您上傳之相關內容。',
  ),
  _Article(
    '蒐集目的',
    '本團隊蒐集個人資料之特定目的包含：會員管理與身分驗證、提供與維護本服務、AI 劇本與紀錄片生成、地圖與位置推薦、任務與優惠券核銷、客戶服務與聯繫、系統安全與防止濫用、統計分析與服務改善，以及遵循法令規定。',
  ),
  _Article(
    '利用期間、地區、對象與方式',
    '・期間：您的帳號存續期間，或蒐集目的消失、您申請刪除為止，但法令另有規定者從其規定；\n・地區：本團隊服務與伺服器所在地區；\n・對象：本團隊，及依法有權之機關；\n・方式：以自動化與電子方式處理及利用。',
  ),
  _Article('AI 處理方式', '本服務之 AI 對話、劇本與紀錄片由地端 AI 模型生成，您輸入之內容不會傳送至外部 AI 服務提供者。'),
  _Article(
    '資料分享與揭露',
    '本團隊不會出售或出租您的個人資料。除下列情形外，不會向第三人揭露：\n・經您同意；\n・依法令或主管機關、司法機關之要求；\n・為保護本團隊、其他使用者或公眾之權益所必要；\n・為完成優惠券兌換或任務驗證，而向對應之合作商家提供必要之兌換資訊。',
  ),
  _Article(
    '位置、相機與相簿權限',
    '位置、相機與相簿權限僅於您使用相關功能時才會請求，您可隨時於手機系統設定中關閉。關閉後，部分功能（如附近景點、掃描 QR Code、儲存圖片）將無法使用。',
  ),
  _Article(
    '資料安全',
    '本團隊採取合理之技術與管理措施保護您的個人資料，避免遭未經授權之存取、竄改、毀損或洩漏。惟網際網路傳輸無法保證絕對安全，請您妥善保管帳號密碼。',
  ),
  _Article(
    '您的權利',
    '依個人資料保護法，您得就您的個人資料向本團隊行使下列權利：查詢或請求閱覽、請求製給複本、請求補充或更正、請求停止蒐集、處理或利用，以及請求刪除。請以下列聯絡方式提出，本團隊將於確認身分後依法處理。',
  ),
  _Article('不提供資料之影響', '您得自由選擇是否提供個人資料。若不提供註冊所需資料，或關閉特定權限，本團隊可能無法提供完整服務。'),
  _Article('未成年人', '未滿 18 歲之使用者，應在法定代理人瞭解並同意本政策與服務條款後，始得使用本服務。'),
  _Article('本機儲存', '本服務僅使用裝置本機儲存記錄登入狀態與偏好設定，您可透過清除 App 資料移除。'),
  _Article('政策修訂', '本團隊得隨時修訂本政策並公告於本服務中。修訂後您繼續使用，即視為同意修訂內容。'),
  _Article('聯絡我們', '對本政策或個人資料有任何疑問，或欲行使上述權利，請來信：playtaiwan2026@gmail.com'),
];
