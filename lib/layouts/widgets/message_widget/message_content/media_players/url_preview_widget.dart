import 'dart:convert';
import 'dart:io';

import 'package:bluebubbles/helpers/attachment_helper.dart';
import 'package:bluebubbles/helpers/utils.dart';
import 'package:bluebubbles/managers/current_chat.dart';
import 'package:bluebubbles/managers/method_channel_interface.dart';
import 'package:bluebubbles/managers/settings_manager.dart';
import 'package:bluebubbles/repository/models/attachment.dart';
import 'package:bluebubbles/repository/models/message.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:metadata_fetch/metadata_fetch.dart';
import 'package:http/http.dart' as http;
import 'package:html/dom.dart' as dom;

class UrlPreviewWidget extends StatefulWidget {
  UrlPreviewWidget({
    Key key,
    @required this.linkPreviews,
    @required this.message,
  }) : super(key: key);
  final List<Attachment> linkPreviews;
  final Message message;

  @override
  _UrlPreviewWidgetState createState() => _UrlPreviewWidgetState();
}

class _UrlPreviewWidgetState extends State<UrlPreviewWidget>
    with TickerProviderStateMixin {
  Metadata data;
  String url;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchPreview();
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    fetchPreview();
  }

  /// Returns a File object representing the [attachment]
  File attachmentFile(Attachment attachment) {
    String appDocPath = SettingsManager().appDocDir.path;
    String pathName =
        "$appDocPath/attachments/${attachment.guid}/${attachment.transferName}";
    return File(pathName);
  }

  /// Manually tries to parse out metadata from a given [url]
  Future<Metadata> manuallyGetMetadata(String url) async {
    Metadata meta = new Metadata();

    var response = await http.get(url);
    var document = responseToDocument(response);

    for (dom.Element i in document.head?.children ?? []) {
      if (i.localName != "meta") continue;
      i.attributes.forEach((dynamic name, String value) {
        String prop = name as String;
        if (prop != "property" && prop != "name") return;
        if (value.contains("title")) {
          meta.title = i.attributes["content"];
        } else if (value.contains("description")) {
          meta.description = i.attributes["content"];
        }
      });
    }

    return meta;
  }

  Future<void> fetchPreview() async {
    // Try to get any already loaded attachment data
    if (CurrentChat().urlPreviews?.containsKey(widget.message.text) != null) {
      data = CurrentChat().urlPreviews[widget.message.text];
    }

    if (data != null || isEmptyString(widget.message.text) || isLoading) return;

    // Let the UI know we are loading
    if (this.mounted) {
      setState(() {
        isLoading = true;
      });
    }

    // Make sure there is a schema with the URL
    url = widget.message.text;
    if (!widget.message.text.toLowerCase().startsWith("http://") &&
        !widget.message.text.toLowerCase().startsWith("https://")) {
      url = "https://" + widget.message.text;
    }

    // Handle specific cases
    if (url.contains('youtube.com/watch?v=') || url.contains("youtu.be/")) {
      // Manually request this URL
      String newUrl = "https://www.youtube.com/oembed?url=$url";
      var response = await http.get(newUrl);

      // Manually load it into a metadata object via JSON
      data = Metadata.fromJson(jsonDecode(response.body));

      // Set the URL to the original URL
      data.url = url;
    } else if (url.contains("twitter.com") && url.contains("/status/")) {
      // Manually request this URL
      String newUrl = "https://publish.twitter.com/oembed?url=$url";
      var response = await http.get(newUrl);

      // Manually load it into a metadata object via JSON
      Map res = jsonDecode(response.body);
      data = new Metadata();
      data.title = (res.containsKey("author_name")) ? res["author_name"] : "";
      data.description = (res.containsKey("html"))
          ? stripHtmlTags(res["html"].replaceAll("<br>", "\n")).trim()
          : "";

      // Set the URL to the original URL
      data.url = url;
    } else if (url.contains("linkedin.com/posts/")) {
      data = await this.manuallyGetMetadata(url);
      data.url = url;
    } else {
      data = await extract(url);
    }

    // If the data or title was null, try to manually parse
    if (data == null || data.title == null) {
      data = await this.manuallyGetMetadata(url);
      data.url = url;
    }

    // Save the metadata
    CurrentChat().urlPreviews[widget.message.text] = data;

    // Let the UI know we are done loading
    if (this.mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget titleWidget = Container();
    if (data == null && isLoading) {
      titleWidget = Text("Loading...",
          style:
              Theme.of(context).textTheme.bodyText1.apply(fontWeightDelta: 2));
    } else if (data != null && data.title != null) {
      titleWidget = Text(
        data.title,
        style: Theme.of(context).textTheme.bodyText1.apply(fontWeightDelta: 2),
        overflow: TextOverflow.ellipsis,
        maxLines: 2,
      );
    }

    return AnimatedSize(
      curve: Curves.easeInOut,
      alignment: Alignment.center,
      duration: Duration(milliseconds: 500),
      vsync: this,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Material(
            color: Theme.of(context).accentColor,
            child: InkResponse(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                MethodChannelInterface()
                    .invokeMethod("open-link", {"link": url});
              },
              child: Container(
                width: MediaQuery.of(context).size.width * 2 / 3,
                child: Column(
                  children: <Widget>[
                    widget.linkPreviews.length > 1
                        ? AttachmentHelper.attachmentExists(
                                widget.linkPreviews.last)
                            ? Image.file(
                                attachmentFile(widget.linkPreviews.last),
                                filterQuality: FilterQuality.low,
                              )
                            : Container()
                        : Container(),
                    Padding(
                      padding:
                          EdgeInsets.only(left: 14.0, right: 14.0, top: 14.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Flexible(
                              fit: FlexFit.tight,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  titleWidget,
                                  data != null && data.description != null
                                      ? Padding(
                                          padding: EdgeInsets.only(top: 5.0),
                                          child: Text(
                                            data.description,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyText1
                                                .apply(fontSizeDelta: -5),
                                          ))
                                      : Container(),
                                  Padding(
                                      padding: EdgeInsets.only(
                                          top: 5.0, bottom: 10.0),
                                      child: Text(
                                        widget.message.text
                                            .replaceAll("https://", "")
                                            .replaceAll("http://", ""),
                                        style: Theme.of(context)
                                            .textTheme
                                            .subtitle2,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ))
                                ],
                              )),
                          (widget.linkPreviews.length == 1)
                              ? Padding(
                                  padding:
                                      EdgeInsets.only(left: 10.0, bottom: 10.0),
                                  child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10.0),
                                      child: Image.file(
                                        attachmentFile(
                                            widget.linkPreviews.first),
                                        width: 40,
                                        fit: BoxFit.contain,
                                      )))
                              : Container()
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
