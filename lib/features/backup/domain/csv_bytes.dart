import 'dart:convert';

/// CSV 文字列へ UTF-8 BOM を付ける。
///
/// Excel（日本語 Windows）が UTF-8 と判別できるようにするため、
/// 共有・ファイル書き出しの直前にのみ付与する。
String withUtf8Bom(String csv) => '\uFEFF$csv';

/// [csv] を UTF-8 BOM 付きバイト列にする。
///
/// `codeUnits` は使わない（日本語が壊れる）。必ず `utf8.encode` を通す。
List<int> csvBytes(String csv) => utf8.encode(withUtf8Bom(csv));
