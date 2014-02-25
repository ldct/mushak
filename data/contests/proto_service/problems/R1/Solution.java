import java.io.*;

public class Solution {

	/**
	 * @param args
	 */
	public static void main(String[] args) {
		String line;
		BufferedReader in = new BufferedReader(new InputStreamReader(System.in));
		try {
			line = in.readLine().trim();	
			if(line!="") {
				String[] numbers = line.split(" ");
				int num1 = Integer.parseInt(numbers[0]);
				int num2 = Integer.parseInt(numbers[1]);
				float result = (num1 + num2) / 2;
				BufferedWriter out = new BufferedWriter(new OutputStreamWriter(System.out));
				out.write(Float.toString(result));
				out.flush();
			}
		} catch (Exception e) {
			e.printStackTrace();
		}			

	}

}