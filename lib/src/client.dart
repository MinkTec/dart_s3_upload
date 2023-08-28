import 'package:dart_s3_upload/enum/acl.dart';
import 'package:amazon_cognito_identity_dart_2/sig_v4.dart';
import 'package:dart_s3_upload/src/client_response.dart';
import 'package:dart_s3_upload/src/content.dart';
import 'package:dart_s3_upload/src/policy.dart';
import 'package:dart_s3_upload/src/utils.dart';
import 'package:http/http.dart' as http;
import 'package:recase/recase.dart';
import 'package:optionals/optionals.dart';

abstract class S3Client {
  final String accessKey;
  final String secretKey;
  final String region;
  final String bucket;
  final ACL acl;
  S3Client(
      {required this.accessKey,
      required this.secretKey,
      required this.region,
      required this.bucket,
      this.acl = ACL.private});

  String get endpoint;

  Future<Result<ClientResponse>> upload(UploadableContent content) async {
    final req = await _request(content);
    req.files.add(await content.filestream);

    try {
      final res = await req.send();
      return Result(await ClientResponse.fromResponse(res, content));
    } catch (e) {
      return Result(e);
    }
  }

  Future<http.MultipartRequest> _request(UploadableContent content) async {
    // Convert metadata to AWS-compliant params before generating the policy.
    final metadataParams = S3Client._convertMetadataToParams(content.metadata);

    final req = http.MultipartRequest("POST", Uri.parse(endpoint));

    // Generate pre-signed policy.
    final policy = Policy.fromS3PresignedPost(
      content.uploadKey,
      bucket,
      accessKey,
      15,
      await content.length,
      acl,
      region: region,
      metadata: metadataParams,
    );

    final signingKey =
        SigV4.calculateSigningKey(secretKey, policy.datetime, region, 's3');
    final signature = SigV4.calculateSignature(signingKey, policy.encode());
    print(policy);

    req.fields['key'] = policy.key;
    req.fields['acl'] = aclToString(acl);
    req.fields['X-Amz-Credential'] = policy.credential;
    req.fields['X-Amz-Algorithm'] = 'AWS4-HMAC-SHA256';
    req.fields['X-Amz-Date'] = policy.datetime;
    req.fields['Policy'] = policy.encode();
    req.fields['X-Amz-Signature'] = signature;
    req.fields['Content-Type'] = content.contentType;

    // If metadata isn't null, add metadata params to the request.
    if (content.metadata != null) {
      req.fields.addAll(metadataParams);
    }
    return req;
  }

  /// A method to transform the map keys into the format compliant with AWS.
  /// AWS requires that each metadata param be sent as `x-amz-meta-*`.
  static Map<String, String> _convertMetadataToParams(
      Map<String, String>? metadata) {
    Map<String, String> updatedMetadata = {};

    if (metadata != null) {
      for (var k in metadata.keys) {
        updatedMetadata['x-amz-meta-${k.paramCase}'] = metadata[k]!;
      }
    }

    return updatedMetadata;
  }
}

class AwsClient extends S3Client {
  final ACL acl;

  AwsClient({
    required super.accessKey,
    required super.secretKey,
    required super.region,
    required super.bucket,
    this.acl = ACL.private,
  });

  String get endpoint => 'https://$bucket.s3.$region.amazonaws.com';
}

class OVHClient extends S3Client {
  OVHClient(
      {required super.accessKey,
      required super.secretKey,
      required super.region,
      required super.bucket});

  String get endpoint => "https://s3.$region.io.cloud.ovh.net";
}

class StratoClient extends S3Client {
  StratoClient(
      {required super.accessKey,
      required super.secretKey,
      super.acl,
      required super.bucket})
      : super(region: "eu-central-1");

  String get endpoint {
    return "https://s3.hidrive.strato.com/$bucket";
  }
}
