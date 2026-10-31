from django.http import JsonResponse
from django.db import connection
from django.utils import timezone


def health_check(request):
    """
    Health check endpoint for Docker containers, orchestration, and monitoring.
    Verifies service availability and database connectivity.
    """
    db_status = "healthy"
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
    except Exception as exc:
        db_status = f"unhealthy: {str(exc)}"

    is_healthy = db_status == "healthy"
    status_code = 200 if is_healthy else 503

    return JsonResponse(
        {
            "status": "healthy" if is_healthy else "unhealthy",
            "service": "BodhixTech Backend",
            "database": db_status,
            "timestamp": timezone.now().isoformat(),
        },
        status=status_code,
    )

