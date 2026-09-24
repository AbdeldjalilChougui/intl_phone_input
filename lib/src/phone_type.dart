import 'package:phone_numbers_parser/phone_numbers_parser.dart' as pnp;

/// The kind of line a phone number belongs to, as defined by
/// libphonenumber.
enum PhoneType {
  /// A mobile number.
  mobile,

  /// A fixed (landline) number.
  fixedLine,

  /// A number that the metadata cannot tell apart as mobile or fixed line,
  /// as in the North American Numbering Plan (+1).
  fixedLineOrMobile,

  /// Voice over IP.
  voip,

  /// Free phone.
  tollFree,

  /// Premium rate.
  premiumRate,

  /// Cost shared between caller and recipient.
  sharedCost,

  /// Personal number, routed to another line.
  personalNumber,

  /// Universal access number (company number).
  uan,

  /// Pager.
  pager,

  /// Voicemail access.
  voiceMail;

  /// The matching type in phone_numbers_parser, or null for
  /// [fixedLineOrMobile], which is not a metadata category.
  pnp.PhoneNumberType? get parserType => switch (this) {
        mobile => pnp.PhoneNumberType.mobile,
        fixedLine => pnp.PhoneNumberType.fixedLine,
        fixedLineOrMobile => null,
        voip => pnp.PhoneNumberType.voip,
        tollFree => pnp.PhoneNumberType.tollFree,
        premiumRate => pnp.PhoneNumberType.premiumRate,
        sharedCost => pnp.PhoneNumberType.sharedCost,
        personalNumber => pnp.PhoneNumberType.personalNumber,
        uan => pnp.PhoneNumberType.uan,
        pager => pnp.PhoneNumberType.pager,
        voiceMail => pnp.PhoneNumberType.voiceMail,
      };
}
