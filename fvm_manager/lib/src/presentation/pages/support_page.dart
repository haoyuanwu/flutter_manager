part of '../home_page.dart';

class _SupportPage extends StatelessWidget {
  const _SupportPage();

  static const _email = 'qw761754627@163.com';

  Future<void> _copyEmail(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _email));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('反馈邮箱已复制')));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('请我喝个茶', style: AppTextStyles.h1),
              const SizedBox(height: 8),
              const Text(
                '如果 Flutter Manager 帮你省了一点时间，欢迎请我喝杯茶。',
                style: TextStyle(fontSize: 15, color: Colors.black54),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xffe7f3f5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.emoji_food_beverage_outlined,
                      size: 32,
                      color: Color(0xff176b80),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        '谢谢你的支持\n打赏随心，反馈和建议也一样珍贵。',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.7,
                          color: Color(0xff225365),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth >= 650
                      ? (constraints.maxWidth - 20) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    children: [
                      _SupportPaymentCard(
                        width: width,
                        title: '微信支付',
                        asset: 'assets/images/support/wechat-pay.png',
                        color: const Color(0xff07a85a),
                      ),
                      _SupportPaymentCard(
                        width: width,
                        title: '支付宝',
                        asset: 'assets/images/support/alipay.jpg',
                        color: const Color(0xff1677ff),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('用户反馈', style: AppTextStyles.h3),
                      const SizedBox(height: 8),
                      const Text('遇到问题或有功能建议，欢迎邮件联系。'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const SelectableText(
                            _email,
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xff176b80),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _copyEmail(context),
                            icon: const Icon(Icons.copy_outlined, size: 18),
                            label: const Text('复制邮箱'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '反馈问题时，可以附上系统版本、操作步骤和相关截图。',
                        style: TextStyle(color: Colors.black54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportPaymentCard extends StatelessWidget {
  const _SupportPaymentCard({
    required this.width,
    required this.title,
    required this.asset,
    required this.color,
  });

  final double width;
  final String title;
  final String asset;
  final Color color;

  void _enlarge(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                child: Row(
                  children: [
                    Expanded(child: Text(title, style: AppTextStyles.h3)),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: InteractiveViewer(
                    maxScale: 4,
                    child: Image.asset(
                      asset,
                      fit: BoxFit.contain,
                      semanticLabel: '$title收款码',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              color: color.withValues(alpha: .08),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            InkWell(
              onTap: () => _enlarge(context),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Image.asset(
                  asset,
                  height: 360,
                  fit: BoxFit.contain,
                  semanticLabel: '$title收款码，点击放大',
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextButton.icon(
                onPressed: () => _enlarge(context),
                icon: const Icon(Icons.zoom_in, size: 18),
                label: const Text('点击放大扫码'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
