import 'package:amazon_cognito_identity_dart_2/sig_v4.dart';

import './client.dart';
import './content.dart';

class SignedRequestParams {
  final Uri uri;
  final Map<String, String> params;

  SignedRequestParams(this.uri, this.params);

  factory SignedRequestParams.fromClientAndContent(
      {required S3Client client,
      required UploadableContent content,
      Map<String, String>? queryParams}) {
    final unencodedPath = "${client.bucket}/${content.uploadKey}";
    final uri = Uri.https(client.endpoint, unencodedPath, queryParams);
    final payload = SigV4.hashCanonicalRequest('');
    final datetime = SigV4.generateDatetime();
    final credentialScope =
        SigV4.buildCredentialScope(datetime, client.region, "s3");

    final canonicalQuery = SigV4.buildCanonicalQueryString(queryParams);
    final canonicalRequest = '''POST
${'/$unencodedPath'.split('/').map(Uri.encodeComponent).join('/')}
$canonicalQuery
host:${client.endpoint}
x-amz-content-sha256:$payload
x-amz-date:$datetime
host;x-amz-content-sha256;x-amz-date;x-amz-security-token
$payload''';

    final stringToSign = SigV4.buildStringToSign(datetime, credentialScope,
        SigV4.hashCanonicalRequest(canonicalRequest));
    final signingKey = SigV4.calculateSigningKey(
        client.secretKey, datetime, client.region, "s3");
    final signature = SigV4.calculateSignature(signingKey, stringToSign);

    final authorization = [
      'AWS4-HMAC-SHA256 Credential=${client.accessKey}/$credentialScope',
      'SignedHeaders=host;x-amz-content-sha256;x-amz-date;x-amz-security-token',
      'Signature=$signature',
    ].join(',');

    return SignedRequestParams(uri, {
      'Authorization': authorization,
      'x-amz-content-sha256': payload,
      'x-amz-date': datetime,
    });
  }
}
