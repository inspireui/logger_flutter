part of logger_flutter;

int _bufferSize = 250;

final ValueNotifier<List<TextSpan>> filteredBuffer =
    ValueNotifier<List<TextSpan>>([]);

class LogConsole extends StatefulWidget {
  final bool dark;
  final bool showCloseButton;
  final bool borderEnable;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final bool isRoot;

  LogConsole({
    this.dark = false,
    this.showCloseButton = false,
    this.borderEnable = true,
    this.padding,
    this.backgroundColor,
    this.isRoot = false,
  }) : super(
          key: isRoot ? rootKey : null,
        );

  @override
  LogConsoleState createState() => LogConsoleState();
}

class LogConsoleState extends State<LogConsole> {
  var _scrollController = ScrollController();
  double _logFontSize = 14;
  bool _scrollListenerEnabled = true;
  bool _followBottom = true;
  StreamSubscription? _sub;

  static StreamSubscription listenEvent({bool dark = false}) {
    return eventBus.on<LogMessage>().listen((event) {
      var buffers = List<TextSpan>.from(filteredBuffer.value);
      if (buffers.length == _bufferSize) {
        buffers.removeAt(0);
      }
      var parser = AnsiParser(dark: dark);
      parser.parse(event.message);
      buffers.add(TextSpan(children: parser.spans));
      filteredBuffer.value = buffers;
    });
  }

  static void clearLog() {
    filteredBuffer.value = <TextSpan>[];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted) {
        if (widget.isRoot) {
          _sub = eventBus.on<LogMessage>().listen((event) {
            var buffers = List<TextSpan>.from(filteredBuffer.value);
            if (buffers.length == _bufferSize) {
              buffers.removeAt(0);
            }
            buffers.add(_renderMessage(event.message));
            filteredBuffer.value = buffers;
          });
        }
        _scrollController.addListener(listener);
      }
    });
  }

  void listener() {
    if (!_scrollListenerEnabled) return;
    var scrolledToBottom =
        _scrollController.offset >= _scrollController.position.maxScrollExtent;
    _followBottom = scrolledToBottom;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(listener);
    _sub?.cancel();
    if (widget.isRoot) {
      filteredBuffer.value = <TextSpan>[];
    }
    super.dispose();
  }

  TextSpan _renderMessage(String message) {
    var parser = AnsiParser(dark: widget.dark);
    parser.parse(message);
    return TextSpan(children: parser.spans);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.withOpacity(0.0),
      body: Container(
        padding: widget.borderEnable ? EdgeInsets.all(10) : null,
        decoration: widget.borderEnable
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: widget.backgroundColor,
                border: Border.all(
                  color: Colors.grey,
                  width: 5.0,
                ),
              )
            : BoxDecoration(color: widget.backgroundColor),
        child: _buildLogContent(),
      ),
      floatingActionButton: AnimatedOpacity(
        opacity: _followBottom ? 0 : 1,
        duration: Duration(milliseconds: 150),
        child: Padding(
          padding: EdgeInsets.only(bottom: 20),
          child: FloatingActionButton(
            mini: true,
            clipBehavior: Clip.antiAlias,
            child: Icon(
              Icons.arrow_downward,
              color: widget.dark ? Colors.white : Colors.lightBlue[900],
            ),
            onPressed: _scrollToBottom,
          ),
        ),
      ),
    );
  }

  Widget _buildLogContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          padding: widget.borderEnable ? EdgeInsets.all(10) : widget.padding,
          height: constraints.maxHeight,
          decoration: widget.borderEnable
              ? BoxDecoration(
                  color: widget.backgroundColor,
                  borderRadius: BorderRadius.circular(10))
              : null,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 1600,
              child: ValueListenableBuilder<List<TextSpan>>(
                valueListenable: filteredBuffer,
                builder: (context, value, child) {
                  return ListView.builder(
                    shrinkWrap: true,
                    controller: _scrollController,
                    itemBuilder: (context, index) {
                      var logEntry = value[index];
                      return Text.rich(
                        logEntry,
                        style: GoogleFonts.lato(fontSize: _logFontSize),
                      );
                    },
                    itemCount: value.length,
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _scrollToBottom() async {
    _scrollListenerEnabled = false;

    _followBottom = true;
    if (mounted) {
      setState(() {});
    }

    var scrollPosition = _scrollController.position;
    await _scrollController.animateTo(
      scrollPosition.maxScrollExtent,
      duration: new Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );

    _scrollListenerEnabled = true;
  }
}
