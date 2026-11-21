USE [QuanLyKyGuiThoiTrang];
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET XACT_ABORT ON;
GO

/* Cho phép chạy lại script an toàn (dùng trong chuỗi nâng cấp build.bat) */
DROP TRIGGER IF EXISTS dbo.TR_SAN_PHAM;
DROP TRIGGER IF EXISTS dbo.TR_CTDH;
DROP TRIGGER IF EXISTS dbo.TR_DON_HANG;
DROP TRIGGER IF EXISTS dbo.TR_THANH_TOAN;
DROP TRIGGER IF EXISTS dbo.TR_CTTTKG;
DROP TRIGGER IF EXISTS dbo.TR_PTTKG;
GO

DROP FUNCTION IF EXISTS dbo.fn_TrangThaiPhieuKyGui;
GO

/* ============================================================
   Hàm xác định trạng thái phiếu ký gửi từ trạng thái sản phẩm
   ============================================================ */
CREATE FUNCTION dbo.fn_TrangThaiPhieuKyGui(@MaPKG INT)
RETURNS NVARCHAR(20)
AS
BEGIN
    DECLARE @TrangThai NVARCHAR(20);

    IF EXISTS (SELECT 1 FROM dbo.SAN_PHAM WHERE MaPKG = @MaPKG AND TrangThaiTiepNhan = N'Chờ xử lý')
        SET @TrangThai = N'Đang xử lý';
    ELSE IF NOT EXISTS (SELECT 1 FROM dbo.SAN_PHAM WHERE MaPKG = @MaPKG AND TrangThaiTiepNhan = N'Đã chấp nhận')
        SET @TrangThai = N'Đã hủy';
    ELSE IF EXISTS
    (
        SELECT 1
        FROM dbo.SAN_PHAM sp
        WHERE sp.MaPKG = @MaPKG
          AND sp.TrangThaiTiepNhan = N'Đã chấp nhận'
          AND
          (
              sp.TrangThaiBan IN (N'Chưa đăng bán', N'Đang bán', N'Đang giữ')
              OR
              (
                  sp.TrangThaiBan = N'Đã bán'
                  AND EXISTS
                  (
                      SELECT 1
                      FROM dbo.CHI_TIET_DON_HANG c
                      JOIN dbo.DON_HANG d ON d.MaDH = c.MaDH
                      WHERE c.MaSP = sp.MaSP
                        AND d.TrangThai NOT IN (N'Hoàn tất', N'Đã hủy')
                  )
              )
          )
    )
        SET @TrangThai = N'Đang ký gửi';
    ELSE
        SET @TrangThai = N'Đã hoàn tất';

    RETURN @TrangThai;
END
GO

/* ============================================================
   TR_SAN_PHAM: kiểm tra trả hàng + cập nhật trạng thái phiếu
   ============================================================ */
CREATE TRIGGER dbo.TR_SAN_PHAM
ON dbo.SAN_PHAM
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        JOIN deleted d ON d.MaSP = i.MaSP
        WHERE i.TrangThaiBan = N'Đã trả lại'
          AND (d.TrangThaiBan IS NULL OR d.TrangThaiBan <> N'Đã trả lại')
          AND
          (
              (d.TrangThaiBan IS NULL OR d.TrangThaiBan NOT IN (N'Chưa đăng bán', N'Đang bán'))
              OR EXISTS
              (
                  SELECT 1
                  FROM dbo.CHI_TIET_DON_HANG c
                  JOIN dbo.DON_HANG dh ON dh.MaDH = c.MaDH
                  WHERE c.MaSP = i.MaSP AND dh.TrangThai <> N'Đã hủy'
              )
          )
    )
    BEGIN
        THROW 50001, N'Không thể trả lại: sản phẩm đang giữ/đã bán hoặc đang thuộc đơn hàng chưa hủy.', 1;
    END

    UPDATE p
    SET TrangThai = dbo.fn_TrangThaiPhieuKyGui(p.MaPKG)
    FROM dbo.PHIEU_KY_GUI p
    WHERE p.MaPKG IN (SELECT MaPKG FROM inserted UNION SELECT MaPKG FROM deleted)
      AND p.TrangThai <> dbo.fn_TrangThaiPhieuKyGui(p.MaPKG);
END
GO

/* ============================================================
   TR_CTDH: giữ hàng khi thêm, trả hàng khi xóa
   ============================================================ */
CREATE TRIGGER dbo.TR_CTDH
ON dbo.CHI_TIET_DON_HANG
AFTER INSERT, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM inserted i
            JOIN dbo.SAN_PHAM sp ON sp.MaSP = i.MaSP
            JOIN dbo.DON_HANG dh ON dh.MaDH = i.MaDH
            WHERE dh.TrangThai <> N'Chờ thanh toán'
               OR sp.TrangThaiBan IS NULL
               OR sp.TrangThaiBan <> N'Đang bán'
               OR sp.GiaDangBan IS NULL
               OR i.GiaNiemYetLucBan <> sp.GiaDangBan
               OR EXISTS
               (
                   SELECT 1
                   FROM dbo.CHI_TIET_DON_HANG c2
                   JOIN dbo.DON_HANG d2 ON d2.MaDH = c2.MaDH
                   WHERE c2.MaSP = i.MaSP
                     AND c2.MaCTDH <> i.MaCTDH
                     AND d2.TrangThai <> N'Đã hủy'
               )
        )
        BEGIN
            THROW 50002, N'Không thể thêm sản phẩm: đơn phải Chờ thanh toán, sản phẩm phải Đang bán, đúng giá niêm yết và chưa thuộc đơn khác.', 1;
        END

        UPDATE sp
        SET TrangThaiBan = N'Đang giữ'
        FROM dbo.SAN_PHAM sp
        JOIN inserted i ON i.MaSP = sp.MaSP;
    END

    IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM deleted d
            JOIN dbo.DON_HANG dh ON dh.MaDH = d.MaDH
            WHERE dh.TrangThai <> N'Chờ thanh toán'
        )
        BEGIN
            THROW 50003, N'Chỉ được xóa sản phẩm khỏi đơn đang Chờ thanh toán.', 1;
        END

        UPDATE sp
        SET TrangThaiBan = N'Đang bán'
        FROM dbo.SAN_PHAM sp
        JOIN deleted d ON d.MaSP = sp.MaSP
        JOIN dbo.DON_HANG dh ON dh.MaDH = d.MaDH
        WHERE dh.TrangThai = N'Chờ thanh toán' AND sp.TrangThaiBan = N'Đang giữ';
    END
END
GO

/* ============================================================
   TR_DON_HANG: chuyển trạng thái, hủy, hoàn tất
   ============================================================ */
CREATE TRIGGER dbo.TR_DON_HANG
ON dbo.DON_HANG
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM deleted d
        JOIN inserted i ON i.MaDH = d.MaDH
        WHERE d.TrangThai IN (N'Hoàn tất', N'Đã hủy')
          AND
          (
              i.TrangThai <> d.TrangThai
              OR i.MaKH <> d.MaKH
              OR i.MaNV <> d.MaNV
              OR i.NgayLap <> d.NgayLap
              OR i.HanThanhToan <> d.HanThanhToan
              OR ISNULL(i.GhiChu,'') <> ISNULL(d.GhiChu,'')
          )
    )
        THROW 50004, N'Đơn hàng đã Hoàn tất/Đã hủy không được sửa.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM deleted d
        JOIN inserted i ON i.MaDH = d.MaDH
        WHERE (d.TrangThai = N'Chờ thanh toán' AND i.TrangThai NOT IN (N'Chờ thanh toán', N'Đang xử lý', N'Đã hủy'))
           OR (d.TrangThai = N'Đang xử lý' AND i.TrangThai NOT IN (N'Đang xử lý', N'Hoàn tất'))
           OR (d.TrangThai IN (N'Hoàn tất', N'Đã hủy') AND i.TrangThai <> d.TrangThai)
    )
        THROW 50005, N'Chuyển trạng thái đơn hàng không hợp lệ.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        WHERE i.TrangThai = N'Đã hủy'
          AND
          (
              EXISTS (SELECT 1 FROM dbo.THANH_TOAN_DON_HANG t WHERE t.MaDH = i.MaDH AND t.TrangThai = N'Thành công')
              OR EXISTS (SELECT 1 FROM dbo.THANH_TOAN_DON_HANG t WHERE t.MaDH = i.MaDH AND t.TrangThai = N'Chờ xử lý')
          )
    )
        THROW 50006, N'Không thể hủy đơn: đã có thanh toán thành công hoặc giao dịch đang xử lý.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        WHERE i.TrangThai = N'Hoàn tất'
          AND
          (
              NOT EXISTS (SELECT 1 FROM dbo.CHI_TIET_DON_HANG c WHERE c.MaDH = i.MaDH)
              OR EXISTS
              (
                  SELECT 1
                  FROM dbo.CHI_TIET_DON_HANG c
                  JOIN dbo.SAN_PHAM sp ON sp.MaSP = c.MaSP
                  WHERE c.MaDH = i.MaDH AND sp.TrangThaiBan <> N'Đã bán'
              )
              OR
              (
                  SELECT ISNULL(SUM(t.SoTien),0)
                  FROM dbo.THANH_TOAN_DON_HANG t
                  WHERE t.MaDH = i.MaDH AND t.TrangThai = N'Thành công'
              )
              <
              (
                  SELECT ISNULL(SUM(c.GiaBanThucTe),0)
                  FROM dbo.CHI_TIET_DON_HANG c
                  WHERE c.MaDH = i.MaDH
              )
          )
    )
        THROW 50007, N'Không thể hoàn tất: đơn chưa thanh toán đủ hoặc sản phẩm chưa Đã bán.', 1;

    UPDATE sp
    SET TrangThaiBan = N'Đang bán'
    FROM dbo.SAN_PHAM sp
    JOIN dbo.CHI_TIET_DON_HANG c ON c.MaSP = sp.MaSP
    JOIN inserted i ON i.MaDH = c.MaDH
    WHERE i.TrangThai = N'Đã hủy' AND sp.TrangThaiBan = N'Đang giữ';

    UPDATE p
    SET TrangThai = dbo.fn_TrangThaiPhieuKyGui(p.MaPKG)
    FROM dbo.PHIEU_KY_GUI p
    WHERE p.MaPKG IN
    (
        SELECT DISTINCT sp.MaPKG
        FROM inserted i
        JOIN dbo.CHI_TIET_DON_HANG c ON c.MaDH = i.MaDH
        JOIN dbo.SAN_PHAM sp ON sp.MaSP = c.MaSP
    )
      AND p.TrangThai <> dbo.fn_TrangThaiPhieuKyGui(p.MaPKG);
END
GO

/* ============================================================
   TR_THANH_TOAN: ghi nhận thanh toán, cập nhật đơn/sản phẩm
   ============================================================ */
CREATE TRIGGER dbo.TR_THANH_TOAN
ON dbo.THANH_TOAN_DON_HANG
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted WHERE TrangThai = N'Thành công')
       AND NOT EXISTS (SELECT 1 FROM inserted)
        THROW 50008, N'Không được xóa giao dịch thanh toán đã thành công.', 1;

    IF EXISTS (SELECT 1 FROM deleted WHERE TrangThai = N'Thành công')
       AND EXISTS (SELECT 1 FROM inserted)
        THROW 50009, N'Không được sửa giao dịch thanh toán đã thành công.', 1;

    IF EXISTS (SELECT 1 FROM inserted WHERE TrangThai = N'Thành công')
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM inserted i
            JOIN dbo.DON_HANG d ON d.MaDH = i.MaDH
            WHERE d.TrangThai IN (N'Đã hủy', N'Hoàn tất')
               OR NOT EXISTS (SELECT 1 FROM dbo.CHI_TIET_DON_HANG c WHERE c.MaDH = i.MaDH)
        )
            THROW 50010, N'Không thể ghi nhận thanh toán: đơn đã kết thúc, đã hủy hoặc không có sản phẩm.', 1;

        ;WITH Paid AS
        (
            SELECT d.MaDH,
                   (SELECT ISNULL(SUM(c.GiaBanThucTe),0) FROM dbo.CHI_TIET_DON_HANG c WHERE c.MaDH = d.MaDH) AS TongTien,
                   (SELECT ISNULL(SUM(t.SoTien),0) FROM dbo.THANH_TOAN_DON_HANG t WHERE t.MaDH = d.MaDH AND t.TrangThai = N'Thành công') AS DaThu
            FROM dbo.DON_HANG d
            WHERE d.MaDH IN (SELECT DISTINCT MaDH FROM inserted)
        )
        UPDATE d
        SET TrangThai = N'Đang xử lý'
        FROM dbo.DON_HANG d
        JOIN Paid p ON p.MaDH = d.MaDH
        WHERE d.TrangThai = N'Chờ thanh toán' AND p.DaThu >= p.TongTien;

        UPDATE sp
        SET TrangThaiBan = N'Đã bán'
        FROM dbo.SAN_PHAM sp
        JOIN dbo.CHI_TIET_DON_HANG c ON c.MaSP = sp.MaSP
        JOIN dbo.DON_HANG d ON d.MaDH = c.MaDH
        WHERE d.MaDH IN (SELECT DISTINCT MaDH FROM inserted)
          AND d.TrangThai = N'Đang xử lý'
          AND sp.TrangThaiBan = N'Đang giữ';
    END
END
GO

/* ============================================================
   TR_CTTTKG: kiểm tra quyết toán
   ============================================================ */
CREATE TRIGGER dbo.TR_CTTTKG
ON dbo.CHI_TIET_THANH_TOAN_KY_GUI
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM deleted d
        JOIN dbo.PHIEU_THANH_TOAN_KY_GUI p ON p.MaPTTKG = d.MaPTTKG
        WHERE p.TrangThai = N'Đã thanh toán'
    )
        THROW 50011, N'Không được sửa/xóa chi tiết của phiếu quyết toán đã thanh toán.', 1;

    IF EXISTS (SELECT 1 FROM inserted)
    BEGIN
        IF EXISTS
        (
            SELECT 1
            FROM inserted i
            JOIN dbo.PHIEU_THANH_TOAN_KY_GUI p ON p.MaPTTKG = i.MaPTTKG
            WHERE p.TrangThai <> N'Chờ thanh toán'
        )
            THROW 50012, N'Chỉ được thêm chi tiết vào phiếu quyết toán đang chờ thanh toán.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM inserted i
            JOIN dbo.CHI_TIET_DON_HANG c ON c.MaCTDH = i.MaCTDH
            JOIN dbo.DON_HANG d ON d.MaDH = c.MaDH
            WHERE d.TrangThai <> N'Hoàn tất'
        )
            THROW 50013, N'Chỉ quyết toán sản phẩm thuộc đơn hàng đã Hoàn tất.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM inserted i
            JOIN dbo.CHI_TIET_DON_HANG c ON c.MaCTDH = i.MaCTDH
            JOIN dbo.SAN_PHAM sp ON sp.MaSP = c.MaSP
            JOIN dbo.PHIEU_KY_GUI pkg ON pkg.MaPKG = sp.MaPKG
            JOIN dbo.PHIEU_THANH_TOAN_KY_GUI p ON p.MaPTTKG = i.MaPTTKG
            WHERE pkg.MaKH <> p.MaKH
        )
            THROW 50014, N'Tất cả sản phẩm trong phiếu quyết toán phải thuộc cùng một người ký gửi.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM inserted i
            JOIN dbo.CHI_TIET_DON_HANG c ON c.MaCTDH = i.MaCTDH
            WHERE i.GiaBanTinhToan <> c.GiaBanThucTe
        )
            THROW 50015, N'Giá bán tính toán phải bằng giá bán thực tế của chi tiết đơn hàng.', 1;

        IF EXISTS
        (
            SELECT 1
            FROM inserted i
            JOIN dbo.CHI_TIET_THANH_TOAN_KY_GUI x ON x.MaCTDH = i.MaCTDH AND x.MaCTTTKG <> i.MaCTTTKG
        )
            THROW 50016, N'Chi tiết đơn hàng này đã được quyết toán.', 1;
    END
END
GO

/* ============================================================
   TR_PTTKG: khóa phiếu quyết toán đã thanh toán
   ============================================================ */
CREATE TRIGGER dbo.TR_PTTKG
ON dbo.PHIEU_THANH_TOAN_KY_GUI
AFTER UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (SELECT 1 FROM deleted WHERE TrangThai = N'Đã thanh toán')
        THROW 50017, N'Không được sửa/xóa phiếu quyết toán đã thanh toán.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted i
        WHERE i.TrangThai = N'Đã thanh toán'
          AND NOT EXISTS (SELECT 1 FROM dbo.CHI_TIET_THANH_TOAN_KY_GUI c WHERE c.MaPTTKG = i.MaPTTKG)
    )
        THROW 50018, N'Không thể thanh toán phiếu quyết toán không có chi tiết.', 1;
END
GO

PRINT N'Triggers created.';
GO
