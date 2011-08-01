package infomap.thumbnailr;

import infomap.utils.CommandUtils;


import java.io.*;
import java.util.*;

import javax.servlet.*;
import javax.servlet.http.*;

import com.maxstocker.jdoctopdf.doctree.DocumentElement;
import com.maxstocker.jdoctopdf.parsers.DocParser;
import com.maxstocker.jdoctopdf.writers.PDFWriter;



public class GenerateThumbnail extends HttpServlet {

	private static final long serialVersionUID = 1L;
	
	//private String wkPath = "C:\\Program Files\\wkhtmltopdf\\wkhtmltoimage.exe";
	private String wkPath = "/home/skonecni/programs/atlassian-jira-enterprise-4.0-standalone/atlassian-jira/infomap/apps/wkhtmltoimage-i386";
	
	//private String thumbnailPath = "C:\\temp\\";
	private String thumbnailPath = "/home/skonecni/programs/atlassian-jira-enterprise-4.0-standalone/atlassian-jira/infomap/thumbnails/";
	
	private String pdf2ImgPath = "/home/skonecni/programs/atlassian-jira-enterprise-4.0-standalone/atlassian-jira/infomap/apps/pdfbox-app-1.6.0.jar";
	
	private String tempPath = "/home/skonecni/programs/atlassian-jira-enterprise-4.0-standalone/atlassian-jira/infomap/temp/";
	
	public void doGet(HttpServletRequest request,
                    HttpServletResponse response)
      throws ServletException, IOException {
		PrintWriter out = response.getWriter();
	
		String url = request.getParameter("url");
		String imgName = request.getParameter("imgName");
		
		out.println(url);
		
		ArrayList<String> command = new ArrayList<String>();

		System.out.println("******File Extension is***********");
		System.out.println(url.substring(url.length()-4, url.length()));
		if(".pdf".equals(url.substring(url.length()-4, url.length())))
		{
			System.out.println("******FILE IS A PDF***********");
			createImageFromPdf(url,imgName);
			
		}else if(".doc".equals(url.substring(url.length()-4, url.length())))
		{
			
			
			DocParser parser = new DocParser();
			
			InputStream in = new FileInputStream(url);
			
			OutputStream pdfFileStream = new FileOutputStream(thumbnailPath + imgName + ".pdf");
			
			DocumentElement doc = parser.parse(in,true,false);
			
			PDFWriter writer = new PDFWriter();
			
			writer.writeDocument(doc, pdfFileStream);
			in.close();
			pdfFileStream.close();
			
			File pdfFile = new File(thumbnailPath + imgName + ".pdf");
			createImageFromPdf(pdfFile.getAbsolutePath(),imgName);
			
			pdfFile.delete();
			
		}else{
		
			command.add(wkPath);
			command.add("--quality");
			command.add("70");
			command.add("--height");
			command.add("800");
			command.add("--crop-w");
			command.add("800");	
			command.add(url);
			command.add(thumbnailPath + imgName + ".jpg");
			runCommand(command);
		}
		
		
		out.close();
  }
	
	private void runCommand(ArrayList<String> command)
	{
		String[] temp = new String[command.size()];
		
		String[] args = (String[])command.toArray(temp);
		
		System.out.println("***commands is**"+ args.toString());
		
		try
		{
			int result = CommandUtils.runCommand(args);
			System.out.println("Program terminated with status " + result);
		}
		catch (Exception e){
			e.printStackTrace();
		}
	}
	
	private void createImageFromPdf(String url,String imgName)
	{
		
		ArrayList<String> command = new ArrayList<String>();
		
		command.add("java");
		command.add("-jar");
		command.add(pdf2ImgPath);
		command.add("PDFToImage");
		command.add("-imageType");
		command.add("jpg");
//		command.add("-outputPrefix");
//		command.add(imgName);
		command.add("-startPage");
		command.add("1");
		command.add("-endPage");
		command.add("1");
		command.add(url);
		
		runCommand(command);
		
		File pdf = new File(url);
		
		File img = new File(pdf.getParent()+ "/" + pdf.getName().substring(0, pdf.getName().length()-4) + "1.jpg");
		
		
		copyFile(img.getAbsolutePath(), thumbnailPath + imgName +".jpg");
		
		img.delete();
	}
	
	private void copyFile(String src, String dest)
	{
		try{
		InputStream in = new FileInputStream(src);
		OutputStream out = new FileOutputStream(dest);
		byte[] buf = new byte[1024];
		int len;
		while ((len = in.read(buf)) > 0) {
		   out.write(buf, 0, len);
		}
		in.close();
		out.close(); 
		}catch(Exception e)
		{
			e.printStackTrace();
		}
	}
}