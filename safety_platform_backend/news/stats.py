from datetime import timedelta
from django.utils import timezone
from emergencies.models import EmergencyReport
from reports.models import AnonymousReport


def compute_stats(period_days):
    """
    Real numbers for the stat tiles at the top of reports_page.dart,
    replacing its hardcoded _stats map. 'total'/'resolved'/'investigating'
    come from anonymous reports submitted in the period; 'response' is the
    average time-to-respond across emergencies that actually got a
    response in the period, formatted the same way the Flutter mock does
    ("6.2 min"). Falls back to "N/A" when there's no data yet to average.
    """
    since = timezone.now() - timedelta(days=period_days)

    reports = AnonymousReport.objects.filter(created_at__gte=since)
    total = reports.count()
    resolved = reports.filter(status="resolved").count()
    investigating = reports.filter(status="under_investigation").count()

    responded = EmergencyReport.objects.filter(created_at__gte=since, responded_at__isnull=False)
    if responded.exists():
        avg_seconds = sum((e.responded_at - e.created_at).total_seconds() for e in responded) / responded.count()
        response = f"{avg_seconds / 60:.1f} min"
    else:
        response = "N/A"

    return {
        "total": str(total),
        "resolved": str(resolved),
        "investigating": str(investigating),
        "response": response,
    }