class AcAcknowledgement {
  const AcAcknowledgement({required this.status, this.errorMessage});

  final String status;
  final String? errorMessage;

  bool get isTransmitted => status == 'transmitted';
}
