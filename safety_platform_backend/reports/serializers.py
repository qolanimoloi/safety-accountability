from rest_framework import serializers

from .models import AnonymousReport, ReportEvidence

MAX_EVIDENCE_SIZE_BYTES = 50 * 1024 * 1024  # 50MB, matches "Max 50MB per file" in anonymous_page.dart

ALLOWED_EVIDENCE_EXTENSIONS = {
    "jpg", "jpeg", "png", "mp4", "mov", "mp3", "wav", "pdf", "doc", "docx",
}


class ReportEvidenceSerializer(serializers.ModelSerializer):
    file = serializers.SerializerMethodField()
    file_kind = serializers.CharField(read_only=True)

    class Meta:
        model = ReportEvidence
        fields = ["id", "file", "file_kind", "original_filename", "content_type", "size_bytes", "uploaded_at"]
        read_only_fields = fields

    def get_file(self, obj):
        request = self.context.get("request")
        url = obj.file.url
        return request.build_absolute_uri(url) if request else url


class AnonymousReportSubmitSerializer(serializers.ModelSerializer):
    # anonymous_page.dart uploads multiple files per report via
    # FilePicker; DRF takes repeated multipart fields under one key as
    # a list when the view reads request.FILES.getlist(...), so this
    # field exists for schema/validation purposes but the view does the
    # actual multi-file handling (ModelSerializer can't express
    # "many files under one field name" cleanly on its own).
    evidence = serializers.ListField(
        child=serializers.FileField(), required=False, write_only=True
    )

    class Meta:
        model = AnonymousReport
        fields = [
            "category", "location", "description", "urgency",
            "involves_minors", "requires_immediate_action", "evidence",
        ]

    def validate_evidence(self, files):
        for f in files:
            ext = f.name.rsplit(".", 1)[-1].lower() if "." in f.name else ""
            if ext not in ALLOWED_EVIDENCE_EXTENSIONS:
                raise serializers.ValidationError(f"'{f.name}' has an unsupported file type.")
            if f.size > MAX_EVIDENCE_SIZE_BYTES:
                raise serializers.ValidationError(f"'{f.name}' exceeds the 50MB limit.")
        return files

    def create(self, validated_data):
        files = validated_data.pop("evidence", [])
        report = AnonymousReport.objects.create(**validated_data)
        for f in files:
            ReportEvidence.objects.create(
                report=report,
                file=f,
                original_filename=f.name,
                content_type=f.content_type or "",
                size_bytes=f.size,
            )
        return report


class AnonymousReportTrackSerializer(serializers.ModelSerializer):
    """
    What the public "track by code" endpoint returns. Deliberately
    excludes admin_notes — those are for staff investigating the report,
    never shown back to an anonymous submitter.
    """

    category_display = serializers.CharField(source="get_category_display", read_only=True)
    status_display = serializers.CharField(source="get_status_display", read_only=True)
    evidence = ReportEvidenceSerializer(many=True, read_only=True)

    class Meta:
        model = AnonymousReport
        fields = [
            "tracking_code", "category", "category_display", "location",
            "description", "urgency", "status", "status_display",
            "evidence", "created_at",
        ]
        read_only_fields = fields