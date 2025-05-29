enum EFeedOptionType {
  reply,
  repost,
  like,
  zaps,
  quote
}

extension EFeedOptionTypeEx on EFeedOptionType{
  String get text {
    switch (this) {
      case EFeedOptionType.reply:
        return 'Reply';
      case EFeedOptionType.repost:
        return 'Repost';
      case EFeedOptionType.like:
        return 'Like';
      case EFeedOptionType.zaps:
        return 'Zaps';
      case EFeedOptionType.quote:
        return 'Quote';
    }
  }

  String get getIconName {
    switch (this) {
      case EFeedOptionType.reply:
        return 'comment_feed_icon.png';
      case EFeedOptionType.repost:
        return 'repost_feed_icon.png';
      case EFeedOptionType.like:
        return 'like_feed_icon.png';
      case EFeedOptionType.zaps:
        return 'lightning_feed_icon.png';
      case EFeedOptionType.quote:
        return 'quote_feed_icon.png';
    }
  }

  int get kind {
    switch (this) {
      case EFeedOptionType.reply:
        return 1;
      case EFeedOptionType.repost:
        return 6;
      case EFeedOptionType.like:
        return 7;
      case EFeedOptionType.zaps:
        return 9735;
      case EFeedOptionType.quote:
        return 2;
    }
  }
}
