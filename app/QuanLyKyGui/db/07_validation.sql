USE [QuanLyKyGuiThoiTrang];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
GO

PRINT N'===== A. KIEM TRA BAT BIEN NGHIEP VU =====';
GO
;WITH KiemTra AS
(
    SELECT 1 AS STT, N'Không có sản phẩm nằm trong 2 đơn hàng còn hiệu lực' AS NoiDung,
    (
        SELECT COUNT(*) FROM
        (
            SELECT c.MaSP
            FROM dbo.CHI_TIET_DON_HANG c
            JOIN dbo.DON_HANG d ON d.MaDH = c.MaDH
            WHERE d.TrangThai <> N'Đã hủy'
            GROUP BY c.MaSP
            HAVING COUNT(*) > 1
        ) x
    ) AS ViPham
    UNION ALL
    SELECT 2, N'Sản phẩm Đang giữ phải thuộc đơn Chờ thanh toán',
    (
        SELECT COUNT(*)
        FROM dbo.SAN_PHAM sp
        WHERE sp.TrangThaiBan = N'Đang giữ'
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.CHI_TIET_DON_HANG c
              JOIN dbo.DON_HANG d ON d.MaDH = c.MaDH
              WHERE c.MaSP = sp.MaSP AND d.TrangThai = N'Chờ thanh toán'
          )
    )
    UNION ALL
    SELECT 3, N'Sản phẩm Đã bán phải thuộc đơn còn hiệu lực',
    (
        SELECT COUNT(*)
        FROM dbo.SAN_PHAM sp
        WHERE sp.TrangThaiBan = N'Đã bán'
          AND NOT EXISTS
          (
              SELECT 1 FROM dbo.CHI_TIET_DON_HANG c
              JOIN dbo.DON_HANG d ON d.MaDH = c.MaDH
              WHERE c.MaSP = sp.MaSP AND d.TrangThai <> N'Đã hủy'
          )
    )
    UNION ALL
    SELECT 4, N'Đơn Hoàn tất/Đang xử lý phải thu đủ tiền',
    (
        SELECT COUNT(*) FROM dbo.vw_DonHang_TongHop
        WHERE TrangThai IN (N'Hoàn tất', N'Đang xử lý') AND DaThu < TongTien
    )
    UNION ALL
    SELECT 5, N'Đơn Chờ thanh toán không được thu đủ tiền',
    (
        SELECT COUNT(*) FROM dbo.vw_DonHang_TongHop
        WHERE TrangThai = N'Chờ thanh toán' AND DaThu >= TongTien
    )
    UNION ALL
    SELECT 6, N'Đơn Đã hủy không có giao dịch thành công hoặc chờ xử lý',
    (
        SELECT COUNT(*)
        FROM dbo.DON_HANG d
        WHERE d.TrangThai = N'Đã hủy'
          AND EXISTS
          (
              SELECT 1 FROM dbo.THANH_TOAN_DON_HANG t
              WHERE t.MaDH = d.MaDH AND t.TrangThai IN (N'Thành công', N'Chờ xử lý')
          )
    )
    UNION ALL
    SELECT 7, N'Chi tiết quyết toán chỉ thuộc đơn đã Hoàn tất',
    (
        SELECT COUNT(*)
        FROM dbo.CHI_TIET_THANH_TOAN_KY_GUI ct
        JOIN dbo.CHI_TIET_DON_HANG c ON c.MaCTDH = ct.MaCTDH
        JOIN dbo.DON_HANG d ON d.MaDH = c.MaDH
        WHERE d.TrangThai <> N'Hoàn tất'
    )
    UNION ALL
    SELECT 8, N'Một phiếu quyết toán chỉ chứa sản phẩm của một người ký gửi',
    (
        SELECT COUNT(*)
        FROM dbo.CHI_TIET_THANH_TOAN_KY_GUI ct
        JOIN dbo.CHI_TIET_DON_HANG c ON c.MaCTDH = ct.MaCTDH
        JOIN dbo.SAN_PHAM sp ON sp.MaSP = c.MaSP
        JOIN dbo.PHIEU_KY_GUI pkg ON pkg.MaPKG = sp.MaPKG
        JOIN dbo.PHIEU_THANH_TOAN_KY_GUI p ON p.MaPTTKG = ct.MaPTTKG
        WHERE pkg.MaKH <> p.MaKH
    )
    UNION ALL
    SELECT 9, N'Hoa hồng 20% và tiền thực nhận tính đúng (so với fn_HoaHong)',
    (
        SELECT COUNT(*) FROM dbo.CHI_TIET_THANH_TOAN_KY_GUI
        WHERE TienHoaHong <> dbo.fn_HoaHong(GiaBanTinhToan)
           OR TienThucNhan <> dbo.fn_ThucNhan(GiaBanTinhToan)
    )
    UNION ALL
    SELECT 10, N'Trạng thái phiếu ký gửi khớp trạng thái sản phẩm',
    (
        SELECT COUNT(*) FROM dbo.PHIEU_KY_GUI p
        WHERE p.TrangThai <> dbo.fn_TrangThaiPhieuKyGui(p.MaPKG)
    )
    UNION ALL
    SELECT 11, N'Giao dịch thành công có ngày hoàn tất, giao dịch khác để trống',
    (
        SELECT COUNT(*) FROM dbo.THANH_TOAN_DON_HANG
        WHERE (TrangThai = N'Thành công' AND NgayHoanTat IS NULL)
           OR (TrangThai <> N'Thành công' AND NgayHoanTat IS NOT NULL)
    )
    UNION ALL
    SELECT 12, N'Đơn đã hủy phải có lý do',
    (
        SELECT COUNT(*) FROM dbo.DON_HANG
        WHERE TrangThai = N'Đã hủy' AND (LyDoHuy IS NULL OR LEN(LTRIM(RTRIM(LyDoHuy))) = 0)
    )
    UNION ALL
    SELECT 13, N'Trạng thái tiếp nhận và trạng thái bán phải nhất quán',
    (
        SELECT COUNT(*) FROM dbo.SAN_PHAM
        WHERE (TrangThaiTiepNhan = N'Đã chấp nhận' AND TrangThaiBan IS NULL)
           OR (TrangThaiTiepNhan <> N'Đã chấp nhận' AND TrangThaiBan IS NOT NULL)
    )
    UNION ALL
    SELECT 14, N'Đơn hàng phải được lập sau ngày sản phẩm được đăng bán',
    (
        SELECT COUNT(*)
        FROM dbo.CHI_TIET_DON_HANG c
        JOIN dbo.DON_HANG d ON d.MaDH = c.MaDH
        JOIN dbo.SAN_PHAM sp ON sp.MaSP = c.MaSP
        WHERE d.TrangThai <> N'Đã hủy' AND sp.NgayDangBan IS NOT NULL AND d.NgayLap < sp.NgayDangBan
    )
    UNION ALL
    SELECT 15, N'Thanh toán phải phát sinh sau khi lập đơn',
    (
        SELECT COUNT(*) FROM dbo.THANH_TOAN_DON_HANG t
        JOIN dbo.DON_HANG d ON d.MaDH = t.MaDH
        WHERE t.NgayTao < d.NgayLap
    )
    UNION ALL
    SELECT 16, N'Phiếu quyết toán phải lập sau ngày bán của sản phẩm',
    (
        SELECT COUNT(*)
        FROM dbo.CHI_TIET_THANH_TOAN_KY_GUI ct
        JOIN dbo.CHI_TIET_DON_HANG c ON c.MaCTDH = ct.MaCTDH
        JOIN dbo.DON_HANG d ON d.MaDH = c.MaDH
        JOIN dbo.PHIEU_THANH_TOAN_KY_GUI p ON p.MaPTTKG = ct.MaPTTKG
        WHERE p.NgayLap < d.NgayLap
    )
    UNION ALL
    SELECT 17, N'Mỗi chi tiết đơn hàng được quyết toán tối đa một lần',
    (
        SELECT COUNT(*) FROM
        (
            SELECT MaCTDH FROM dbo.CHI_TIET_THANH_TOAN_KY_GUI
            GROUP BY MaCTDH HAVING COUNT(*) > 1
        ) x
    )
    UNION ALL
    SELECT 18, N'Phiếu quyết toán đã thanh toán phải có ngày trả tiền',
    (
        SELECT COUNT(*) FROM dbo.PHIEU_THANH_TOAN_KY_GUI
        WHERE (TrangThai = N'Đã thanh toán' AND NgayThanhToan IS NULL)
           OR (TrangThai = N'Chờ thanh toán' AND NgayThanhToan IS NOT NULL)
    )
)
SELECT STT, NoiDung, ViPham,
       CASE WHEN ViPham = 0 THEN N'PASS' ELSE N'FAIL' END AS KetQua
FROM KiemTra
ORDER BY STT;
GO

PRINT N'';
PRINT N'===== B. DO PHU DU LIEU =====';
GO
SELECT N'Phiếu ký gửi' AS Nhom, TrangThai AS GiaTri, COUNT(*) AS SoLuong
FROM dbo.PHIEU_KY_GUI GROUP BY TrangThai
UNION ALL
SELECT N'Sản phẩm - tiếp nhận', TrangThaiTiepNhan, COUNT(*)
FROM dbo.SAN_PHAM GROUP BY TrangThaiTiepNhan
UNION ALL
SELECT N'Sản phẩm - bán', ISNULL(TrangThaiBan, N'(Chưa có)'), COUNT(*)
FROM dbo.SAN_PHAM GROUP BY TrangThaiBan
UNION ALL
SELECT N'Đơn hàng', TrangThai, COUNT(*)
FROM dbo.DON_HANG GROUP BY TrangThai
UNION ALL
SELECT N'Thanh toán', TrangThai, COUNT(*)
FROM dbo.THANH_TOAN_DON_HANG GROUP BY TrangThai
UNION ALL
SELECT N'Quyết toán', TrangThai, COUNT(*)
FROM dbo.PHIEU_THANH_TOAN_KY_GUI GROUP BY TrangThai
ORDER BY Nhom, GiaTri;
GO

PRINT N'';
PRINT N'===== C. DOI SOAT THANH TOAN (CHENH LECH KHAC 0) =====';
GO
SELECT MaDH, TenKhachHang, TrangThai, TongTien, DaThu, ConLai, ChenhLech, KetQuaDoiSoat
FROM dbo.vw_DoiSoat_ThanhToan
WHERE ChenhLech <> 0
ORDER BY MaDH;
GO

PRINT N'';
PRINT N'===== D. CONG NO CHUA QUYET TOAN =====';
GO
SELECT * FROM dbo.vw_CongNo_NguoiKyGui ORDER BY TienPhaiTra DESC;
GO

PRINT N'';
PRINT N'===== E. DOANH THU THEO THANG =====';
GO
SELECT * FROM dbo.vw_DoanhThu_TheoThang ORDER BY Thang;
GO

